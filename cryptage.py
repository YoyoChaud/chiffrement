#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script de sauvegarde, chiffrement et déchiffrement de fichiers
Auteur : YoyoChaud  
Date : 21/08/2024

Ce script permet de :
1. Sauvegarder des fichiers depuis un répertoire source ou un fichier spécifique vers un répertoire de sauvegarde ou un fichier de destination.
2. Chiffrer les fichiers sauvegardés à l'aide de la bibliothèque `cryptography`.
3. Déchiffrer les fichiers sauvegardés pour les restaurer dans leur état original.

Utilisation :
    - Pour sauvegarder et chiffrer : python cryptage.py chiffrer <source> [<destination>] [<chemin_cle (optionnel)>]
    - Pour déchiffrer : python cryptage.py dechiffrer <destination> [<chemin_cle (optionnel)>]

Prérequis :
    - Python 3.x
    - Bibliothèque `cryptography` (à installer via `pip install cryptography`)
"""

import os
import sys
from cryptography.fernet import Fernet
import shutil

def sauvegarder_et_chiffrer(chemin_source, chemin_sauvegarde=None, chemin_cle=None, cle_specifiee=None):
    """
    Sauvegarde et chiffre un fichier ou tous les fichiers d'un dossier.

    Paramètres :
        chemin_source (str): Chemin du fichier ou du répertoire contenant les fichiers à sauvegarder.
        chemin_sauvegarde (str, optionnel): Chemin du répertoire où les fichiers seront sauvegardés et chiffrés. 
                                             Si non fourni, le fichier chiffré sera enregistré à côté du fichier source avec l'extension '.encrypted'.
        chemin_cle (str, optionnel): Chemin où la clé de chiffrement sera sauvegardée. Si non fourni, la clé sera sauvegardée dans le même dossier que les fichiers chiffrés.
        cle_specifiee (bytes, optionnel): Clé de chiffrement fournie par l'utilisateur. Si fournie, elle sera utilisée pour chiffrer les fichiers.
    """
    # Utiliser la clé fournie ou en créer une nouvelle
    if cle_specifiee is not None:
        cle = cle_specifiee
    else:
        cle = Fernet.generate_key()
    
    suite_chiffrement = Fernet(cle)

    # Si le chemin source est un dossier
    if os.path.isdir(chemin_source):
        # Création du répertoire de sauvegarde s'il n'existe pas
        if chemin_sauvegarde is None:
            chemin_sauvegarde = chemin_source + "_chiffre"
        
        if not os.path.exists(chemin_sauvegarde):
            os.makedirs(chemin_sauvegarde)

        # Traitement de chaque fichier dans le répertoire source
        for fichier in os.listdir(chemin_source):
            chemin_fichier_source = os.path.join(chemin_source, fichier)
            chemin_fichier_sauvegarde = os.path.join(chemin_sauvegarde, fichier + '.encrypted')

            # Copier et chiffrer chaque fichier
            shutil.copy(chemin_fichier_source, chemin_fichier_sauvegarde)
            with open(chemin_fichier_sauvegarde, 'rb') as f:
                donnees_fichier = f.read()
                donnees_chiffrees = suite_chiffrement.encrypt(donnees_fichier)

            with open(chemin_fichier_sauvegarde, 'wb') as f:
                f.write(donnees_chiffrees)

    # Si le chemin source est un fichier
    elif os.path.isfile(chemin_source):
        # Si un répertoire de sauvegarde est fourni, ajouter le nom de fichier et l'extension
        if chemin_sauvegarde is not None:
            if not os.path.exists(chemin_sauvegarde):
                os.makedirs(chemin_sauvegarde)
            chemin_sauvegarde = os.path.join(chemin_sauvegarde, os.path.basename(chemin_source) + '.encrypted')
        else:
            chemin_sauvegarde = chemin_source + ".encrypted"
        
        # Copier et chiffrer le fichier
        shutil.copy(chemin_source, chemin_sauvegarde)
        with open(chemin_sauvegarde, 'rb') as f:
            donnees_fichier = f.read()
            donnees_chiffrees = suite_chiffrement.encrypt(donnees_fichier)

        with open(chemin_sauvegarde, 'wb') as f:
            f.write(donnees_chiffrees)

    # Si la clé a été générée, enregistrer la clé de chiffrement
    if chemin_cle is None and cle_specifiee is None:
        chemin_cle = os.path.join(os.path.dirname(chemin_sauvegarde), 'cle.key')
        with open(chemin_cle, 'wb') as fichier_cle:
            fichier_cle.write(cle)
        print(f"Clé de chiffrement générée et sauvegardée à : {chemin_cle}")
    elif chemin_cle is not None:
        with open(chemin_cle, 'wb') as fichier_cle:
            fichier_cle.write(cle)
        print(f"Clé de chiffrement sauvegardée à : {chemin_cle}")

    print(f"Sauvegarde et chiffrement réalisés avec succès.")


def dechiffrer_fichiers(chemin_sauvegarde, chemin_cle=None):
    """
    Déchiffre un fichier ou tous les fichiers d'un dossier.

    Paramètres :
        chemin_sauvegarde (str): Chemin du fichier ou du répertoire où les fichiers chiffrés sont stockés.
        chemin_cle (str, optionnel): Chemin vers la clé de chiffrement. Si non fourni, recherche la clé dans le même dossier que les fichiers chiffrés.
    """
    # Définir l'emplacement de la clé de chiffrement
    if chemin_cle is None:
        chemin_cle = os.path.join(os.path.dirname(chemin_sauvegarde), 'cle.key')

    # Chargement de la clé de chiffrement
    with open(chemin_cle, 'rb') as fichier_cle:
        cle = fichier_cle.read()

    suite_chiffrement = Fernet(cle)

    # Si le chemin de sauvegarde est un dossier
    if os.path.isdir(chemin_sauvegarde):
        for fichier in os.listdir(chemin_sauvegarde):
            if fichier == 'cle.key':
                continue

            chemin_fichier_sauvegarde = os.path.join(chemin_sauvegarde, fichier)

            with open(chemin_fichier_sauvegarde, 'rb') as f:
                donnees_chiffrees = f.read()
                donnees_dechiffrees = suite_chiffrement.decrypt(donnees_chiffrees)

            # Retirer l'extension .encrypted
            chemin_fichier_final = os.path.join(chemin_sauvegarde, fichier.replace('.encrypted', ''))

            with open(chemin_fichier_final, 'wb') as f:
                f.write(donnees_dechiffrees)

            # Supprimer le fichier chiffré
            os.remove(chemin_fichier_sauvegarde)

    # Si le chemin de sauvegarde est un fichier
    elif os.path.isfile(chemin_sauvegarde):
        with open(chemin_sauvegarde, 'rb') as f:
            donnees_chiffrees = f.read()
            donnees_dechiffrees = suite_chiffrement.decrypt(donnees_chiffrees)

        # Retirer l'extension .encrypted
        chemin_fichier_final = chemin_sauvegarde.replace('.encrypted', '')

        with open(chemin_fichier_final, 'wb') as f:
            f.write(donnees_dechiffrees)

        # Supprimer le fichier chiffré
        os.remove(chemin_sauvegarde)

    print("Déchiffrement terminé avec succès.")


if len(sys.argv) < 3:
    print("Usage:")
    print("  Pour sauvegarder et chiffrer : python cryptage.py chiffrer <source> [<destination>] [<chemin_cle (optionnel)>] [<cle_specifiee (optionnel)>]")
    print("  Pour déchiffrer : python cryptage.py dechiffrer <destination> [<chemin_cle (optionnel)>]")
    sys.exit(1)

mode = sys.argv[1]

if mode == 'chiffrer':
    chemin_source = sys.argv[2]
    chemin_sauvegarde = sys.argv[3] if len(sys.argv) > 3 else None
    chemin_cle = sys.argv[4] if len(sys.argv) > 4 else None
    cle_specifiee = sys.argv[5].encode() if len(sys.argv) > 5 else None
    sauvegarder_et_chiffrer(chemin_source, chemin_sauvegarde, chemin_cle, cle_specifiee)

elif mode == 'dechiffrer':
    chemin_sauvegarde = sys.argv[2]
    chemin_cle = sys.argv[3] if len(sys.argv) > 3 else None
    dechiffrer_fichiers(chemin_sauvegarde, chemin_cle)

else:
    print("Arguments incorrects. Veuillez vérifier la commande et réessayer.")
    sys.exit(1)
