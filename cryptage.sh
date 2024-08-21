#!/bin/bash
# -*- coding: utf-8 -*-

# Script de sauvegarde, chiffrement et déchiffrement de fichiers
# Auteur : YoyoChaud  
# Date : 21/08/2024

# Ce script permet de :
# 1. Sauvegarder des fichiers depuis un répertoire source ou un fichier spécifique vers un répertoire de sauvegarde ou un fichier de destination.
# 2. Chiffrer les fichiers sauvegardés à l'aide de la commande `openssl`.
# 3. Déchiffrer les fichiers sauvegardés pour les restaurer dans leur état original.

# Utilisation :
#   - Pour sauvegarder et chiffrer : ./cryptage.sh chiffrer <source> [<destination>] [<chemin_cle (optionnel)>]
#   - Pour déchiffrer : ./cryptage.sh dechiffrer <destination> [<chemin_cle (optionnel)>]

# Prérequis :
#   - Bash (compatible avec les systèmes Unix/Linux)
#   - OpenSSL (à installer via `sudo apt-get install openssl` sur Debian/Ubuntu ou via `brew install openssl` sur macOS)

# Fonction pour sauvegarder et chiffrer un fichier ou tous les fichiers d'un dossier
# Paramètres :
#   - chemin_source : Chemin du fichier ou du répertoire contenant les fichiers à sauvegarder.
#   - chemin_sauvegarde : Chemin du répertoire où les fichiers seront sauvegardés et chiffrés.
#     Si non fourni, le fichier chiffré sera enregistré à côté du fichier source avec l'extension '.encrypted'.
#   - chemin_cle : Chemin où la clé de chiffrement sera sauvegardée. Si non fourni, la clé sera sauvegardée dans le même dossier que les fichiers chiffrés.
#   - cle_specifiee : Clé de chiffrement fournie par l'utilisateur. Si fournie, elle sera utilisée pour chiffrer les fichiers.
sauvegarder_et_chiffrer() {
    local chemin_source=$1
    local chemin_sauvegarde=${2:-}
    local chemin_cle=${3:-}
    local cle_specifiee=${4:-}

    # Générer une clé si elle n'est pas spécifiée
    if [ -z "$cle_specifiee" ]; then
        cle_specifiee=$(openssl rand -base64 32)
        # Si aucun chemin de clé n'est fourni, enregistrer la clé dans le même dossier que les fichiers chiffrés
        if [ -z "$chemin_cle" ]; then
            chemin_cle="$(dirname "$chemin_source")/cle.key"
        fi
        echo "$cle_specifiee" > "$chemin_cle"
        echo "Clé de chiffrement générée et sauvegardée à : $chemin_cle"
    fi

    # Si le chemin source est un dossier
    if [ -d "$chemin_source" ]; then
        # Création du répertoire de sauvegarde s'il n'existe pas
        [ -z "$chemin_sauvegarde" ] && chemin_sauvegarde="${chemin_source}_chiffre"
        mkdir -p "$chemin_sauvegarde"

        # Traitement de chaque fichier dans le répertoire source
        for fichier in "$chemin_source"/*; do
            chemin_fichier_sauvegarde="$chemin_sauvegarde/$(basename "$fichier").encrypted"
            # Copier et chiffrer chaque fichier
            openssl enc -aes-256-cbc -salt -in "$fichier" -out "$chemin_fichier_sauvegarde" -pass pass:"$cle_specifiee"
        done

    # Si le chemin source est un fichier
    elif [ -f "$chemin_source" ]; then
        # Si un répertoire de sauvegarde est fourni, ajouter le nom de fichier et l'extension
        [ -n "$chemin_sauvegarde" ] && chemin_sauvegarde="$chemin_sauvegarde/$(basename "$chemin_source").encrypted" || chemin_sauvegarde="$chemin_source.encrypted"
        # Copier et chiffrer le fichier
        openssl enc -aes-256-cbc -salt -in "$chemin_source" -out "$chemin_sauvegarde" -pass pass:"$cle_specifiee"
    fi

    echo "Sauvegarde et chiffrement réalisés avec succès."
}

# Fonction pour déchiffrer un fichier ou tous les fichiers d'un dossier
# Paramètres :
#   - chemin_sauvegarde : Chemin du fichier ou du répertoire où les fichiers chiffrés sont stockés.
#   - chemin_cle : Chemin vers la clé de chiffrement. Si non fourni, recherche la clé dans le même dossier que les fichiers chiffrés.
dechiffrer_fichiers() {
    local chemin_sauvegarde=$1
    local chemin_cle=${2:-}

    # Définir l'emplacement de la clé de chiffrement
    if [ -z "$chemin_cle" ]; then
        chemin_cle="$(dirname "$chemin_sauvegarde")/cle.key"
    fi

    # Chargement de la clé de chiffrement
    cle_specifiee=$(cat "$chemin_cle")

    # Si le chemin de sauvegarde est un dossier
    if [ -d "$chemin_sauvegarde" ]; then
        for fichier in "$chemin_sauvegarde"/*.encrypted; do
            [ "$fichier" = "$chemin_sauvegarde/cle.key" ] && continue
            chemin_fichier_final="${fichier%.encrypted}"
            openssl enc -aes-256-cbc -d -in "$fichier" -out "$chemin_fichier_final" -pass pass:"$cle_specifiee"
            rm -f "$fichier"
        done

    # Si le chemin de sauvegarde est un fichier
    elif [ -f "$chemin_sauvegarde" ]; then
        chemin_fichier_final="${chemin_sauvegarde%.encrypted}"
        openssl enc -aes-256-cbc -d -in "$chemin_sauvegarde" -out "$chemin_fichier_final" -pass pass:"$cle_specifiee"
        rm -f "$chemin_sauvegarde"
    fi

    echo "Déchiffrement terminé avec succès."
}

# Script principal
if [ $# -lt 2 ]; then
    echo "Usage:"
    echo "  Pour sauvegarder et chiffrer : $0 chiffrer <source> [<destination>] [<chemin_cle (optionnel)>] [<cle_specifiee (optionnel)>]"
    echo "  Pour déchiffrer : $0 dechiffrer <destination> [<chemin_cle (optionnel)>]"
    exit 1
fi

mode=$1

if [ "$mode" == "chiffrer" ]; then
    chemin_source=$2
    chemin_sauvegarde=${3:-}
    chemin_cle=${4:-}
    cle_specifiee=${5:-}
    sauvegarder_et_chiffrer "$chemin_source" "$chemin_sauvegarde" "$chemin_cle" "$cle_specifiee"

elif [ "$mode" == "dechiffrer" ]; then
    chemin_sauvegarde=$2
    chemin_cle=${3:-}
    dechiffrer_fichiers "$chemin_sauvegarde" "$chemin_cle"

else
    echo "Arguments incorrects. Veuillez vérifier la commande et réessayer."
    exit 1
fi
