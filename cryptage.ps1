#!/usr/bin/env pwsh
# -*- coding: utf-8 -*-

<#
.SYNOPSIS
Script de sauvegarde, chiffrement et déchiffrement de fichiers.
Auteur : YoyoChaud  
Date : 21/08/2024

.DESCRIPTION
Ce script permet de :
1. Sauvegarder des fichiers depuis un répertoire source ou un fichier spécifique vers un répertoire de sauvegarde ou un fichier de destination.
2. Chiffrer les fichiers sauvegardés à l'aide de la bibliothèque `System.Security.Cryptography`.
3. Déchiffrer les fichiers sauvegardés pour les restaurer dans leur état original.

.UTILISATION
    - Pour sauvegarder et chiffrer : powershell -File cryptage.ps1 -Mode chiffrer -Source <source> [-Destination <destination>] [-KeyPath <chemin_cle (optionnel)>]
    - Pour déchiffrer : powershell -File cryptage.ps1 -Mode dechiffrer -Destination <destination> [-KeyPath <chemin_cle (optionnel)>]

.PREREQUIS
    - PowerShell 5.x ou plus récent
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$Mode,

    [Parameter(Mandatory=$true)]
    [string]$Source,

    [string]$Destination,

    [string]$KeyPath,

    [string]$SpecifiedKey
)

function SauvegarderEtChiffrer {
    param (
        [string]$SourcePath,
        [string]$BackupPath,
        [string]$KeyPath,
        [string]$SpecifiedKey
    )

    <#
    .SYNOPSIS
    Sauvegarde et chiffre un fichier ou tous les fichiers d'un dossier.

    .PARAMETER SourcePath
    Chemin du fichier ou du répertoire contenant les fichiers à sauvegarder.

    .PARAMETER BackupPath
    Chemin du répertoire où les fichiers seront sauvegardés et chiffrés.
    Si non fourni, le fichier chiffré sera enregistré à côté du fichier source avec l'extension '.encrypted'.

    .PARAMETER KeyPath
    Chemin où la clé de chiffrement sera sauvegardée. Si non fourni, la clé sera sauvegardée dans le même dossier que les fichiers chiffrés.

    .PARAMETER SpecifiedKey
    Clé de chiffrement fournie par l'utilisateur. Si fournie, elle sera utilisée pour chiffrer les fichiers.
    #>

    # Générer une nouvelle clé ou utiliser celle fournie
    if ($null -eq $SpecifiedKey) {
        $key = [System.Convert]::ToBase64String((New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes(32))
    } else {
        $key = $SpecifiedKey
    }

    $aes = New-Object System.Security.Cryptography.AesManaged
    $aes.Key = [System.Convert]::FromBase64String($key)
    $aes.GenerateIV()

    $encryptor = $aes.CreateEncryptor()

    # Sauvegarder la clé si elle a été générée
    if ($null -eq $SpecifiedKey) {
        if ($null -eq $KeyPath) {
            $KeyPath = Join-Path (Split-Path $SourcePath -Parent) "cle.key"
        }
        [System.IO.File]::WriteAllText($KeyPath, $key)
        Write-Host "Clé de chiffrement générée et sauvegardée à : $KeyPath"
    }

    # Si le chemin source est un dossier
    if (Test-Path $SourcePath -PathType Container) {
        if ($null -eq $BackupPath) {
            $BackupPath = "$SourcePath`_chiffre"
        }
        if (-not (Test-Path $BackupPath)) {
            New-Item -ItemType Directory -Path $BackupPath | Out-Null
        }

        # Chiffrer chaque fichier du dossier
        Get-ChildItem -Path $SourcePath | ForEach-Object {
            $fileContent = Get-Content -Path $_.FullName -Raw
            $encryptedData = [System.Security.Cryptography.CryptoStream]::new([System.IO.MemoryStream]::new(), $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
            $encryptedData.Write([System.Text.Encoding]::UTF8.GetBytes($fileContent), 0, [System.Text.Encoding]::UTF8.GetBytes($fileContent).Length)
            $encryptedData.Close()

            $destinationFile = Join-Path $BackupPath "$($_.Name).encrypted"
            [System.IO.File]::WriteAllBytes($destinationFile, $encryptedData.ToArray())
        }
    }
    # Si le chemin source est un fichier
    elseif (Test-Path $SourcePath -PathType Leaf) {
        $fileContent = Get-Content -Path $SourcePath -Raw
        $encryptedData = [System.Security.Cryptography.CryptoStream]::new([System.IO.MemoryStream]::new(), $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
        $encryptedData.Write([System.Text.Encoding]::UTF8.GetBytes($fileContent), 0, [System.Text.Encoding]::UTF8.GetBytes($fileContent).Length)
        $encryptedData.Close()

        if ($null -ne $BackupPath) {
            $destinationFile = Join-Path $BackupPath "$(Split-Path $SourcePath -Leaf).encrypted"
        } else {
            $destinationFile = "$SourcePath.encrypted"
        }
        [System.IO.File]::WriteAllBytes($destinationFile, $encryptedData.ToArray())
    }

    Write-Host "Sauvegarde et chiffrement réalisés avec succès."
}

function DechiffrerFichiers {
    param (
        [string]$BackupPath,
        [string]$KeyPath
    )

    <#
    .SYNOPSIS
    Déchiffre un fichier ou tous les fichiers d'un dossier.

    .PARAMETER BackupPath
    Chemin du fichier ou du répertoire où les fichiers chiffrés sont stockés.

    .PARAMETER KeyPath
    Chemin vers la clé de chiffrement. Si non fourni, recherche la clé dans le même dossier que les fichiers chiffrés.
    #>

    # Charger la clé
    if ($null -eq $KeyPath) {
        $KeyPath = Join-Path (Split-Path $BackupPath -Parent) "cle.key"
    }
    $key = [System.IO.File]::ReadAllText($KeyPath)

    $aes = New-Object System.Security.Cryptography.AesManaged
    $aes.Key = [System.Convert]::FromBase64String($key)
    $aes.GenerateIV()

    $decryptor = $aes.CreateDecryptor()

    # Si le chemin de sauvegarde est un dossier
    if (Test-Path $BackupPath -PathType Container) {
        Get-ChildItem -Path $BackupPath | ForEach-Object {
            if ($_.Name -eq "cle.key") { return }

            $encryptedData = [System.IO.File]::ReadAllBytes($_.FullName)
            $memoryStream = [System.IO.MemoryStream]::new($encryptedData)
            $cryptoStream = [System.Security.Cryptography.CryptoStream]::new($memoryStream, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Read)
            $decryptedData = New-Object System.IO.MemoryStream
            $cryptoStream.CopyTo($decryptedData)

            $destinationFile = $_.FullName -replace '\.encrypted$', ''
            [System.IO.File]::WriteAllBytes($destinationFile, $decryptedData.ToArray())

            # Supprimer le fichier chiffré
            Remove-Item -Path $_.FullName
        }
    }
    # Si le chemin de sauvegarde est un fichier
    elseif (Test-Path $BackupPath -PathType Leaf) {
        $encryptedData = [System.IO.File]::ReadAllBytes($BackupPath)
        $memoryStream = [System.IO.MemoryStream]::new($encryptedData)
        $cryptoStream = [System.Security.Cryptography.CryptoStream]::new($memoryStream, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Read)
        $decryptedData = New-Object System.IO.MemoryStream
        $cryptoStream.CopyTo($decryptedData)

        $destinationFile = $BackupPath -replace '\.encrypted$', ''
        [System.IO.File]::WriteAllBytes($destinationFile, $decryptedData.ToArray())

        # Supprimer le fichier chiffré
        Remove-Item -Path $BackupPath
    }

    Write-Host "Déchiffrement terminé avec succès."
}

if ($Mode -eq 'chiffrer') {
    SauvegarderEtChiffrer -SourcePath $Source -BackupPath $Destination -KeyPath $KeyPath -SpecifiedKey $SpecifiedKey
}
elseif ($Mode -eq 'dechiffrer') {
    DechiffrerFichiers -BackupPath $Source -KeyPath $KeyPath
} else {
    Write-Host "Arguments incorrects. Veuillez vérifier la commande et réessayer."
    exit 1
}
