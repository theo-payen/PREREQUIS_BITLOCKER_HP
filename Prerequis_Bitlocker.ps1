<# 
.SYNOPSIS
    Ce script contrôle et configurer les prérequis de l'application BitLOCKER.
    ce script controle une liste de pc pré défini
   
 
.DESCRIPTION 
    Cibles : Ordinateurs HP
    Test : ouverture de session en tant qu'administrateur local
    Etats retournés :   - PC status
                        - Bitlocker status
                        - BIOS seting
                            - change les paramèrtre BIOS
                            - reboot
                        - Puce TMP ready
                            - active la puce TMP
                        - partition format
                            - change le format
                            - reboot

    Statuts retournés : - prêt a être bitlocker
                        - Déjà Bitlocker
.PARAMETER <ComputerName>
    nom du PC

.PARAMETER <password>
    Mot de passe BIOS

.INPUTS
    -ComputerName [PC] 
    -password [mdpbios]

.OUTPUTS
    Non pris en charge

.EXAMPLE
    .\Prerequis_Bitlocker.ps1 -computerName [PC] -password [mdpbios]

.NOTES
    Version:        1.1
    Auteur:         Théo PAYEN/CAF 77
    Date:           20/07/2021             
    Changements:    Gestion des erreur
                    Ajout de la fonction Get-setingBIOS et Set-setingBIOS pour mieux géré les paramètre BIOS              
#> 
param (
    $computerName,
    $MDP_BIOS
)

# ! Get-rightAdmin
# * Vérification des droits administrateurs
# * si vous n'aviez pas les droits le script s'arrêtera
function Get-rightAdmin {
    if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    }else{
        write-Host "$computerName : Erreur - vous n'aviez pas les droits pour exécuter ce script"
        Exit
    }
}
# ! Get-PingStatus
# * Vérification si l'ordinateur est bien connecté
# * si l'ordinateur n'est pas connecté le script s'arrêtera
function Get-PingStatus {
    Test-Connection $computerName -Count 2 -ErrorAction:SilentlyContinue | Out-Null
    if ($?) {
        write-Host "$computerName : Succès - L'ordinateur est bien connecté"
    }else{
        write-Host "$computerName : Erreur - Impossible de ping l'ordinateur"
        Exit
    }
}
# ! Get-BitLockerStatus
# * Vérification du status Bitlocker 
# * Si bitlocker est en échec la function detect Bitlocker comme désactiver
# * si bitlocker et déjà activer le script s'arrêtera
function Get-BitLockerStatus {
    try {
        $Bit_status = Invoke-Command -ComputerName $computerName -ScriptBlock {
            (Get-BitLockerVolume -MountPoint "C:")
        }
        if ($Bit_status.ProtectionStatus -eq 'Off') {
            write-Host "$computerName : En cours - BitLocker n'est pas activé sur l'ordinateur"
        }elseif ($Bit_status.ProtectionStatus -eq 'On') {
            write-Host "$computerName : Succès - BitLocker est déjà activé sur l'ordinateur"
            Exit
        }else {
            write-Host "$computerName : Erreur - Une erreur est survenue lors de l'exécution de la fonction Get-BitLockerStatus"
            Exit
        }
    }catch{
        write-Host "$computerName : Erreur - Une erreur est survenue lors de l'exécution de la fonction Get-BitLockerStatus"
        Exit    
    }
}
# ! Get-SetingBIOS
# * Vérification de la configuration du paramètre BIOS $name en $currentvalue
# ? comment lancer la fonction Get-SetingBIOS
# ? Get-setingBIOS -name "[nom paramettre BIOS]" -currentvalue "[Nom de la valeur]"
# ! lister les tous les paramètre sur BIOS HP avec la commande
# ! Get-WmiObject -computername $computerName -Namespace root/hp/instrumentedBIOS -Class hp_biosEnumeration
function Get-SetingBIOS {
    param (
        $name,
        $currentvalue
    )
    
    $BIOS = Get-WmiObject -computername $computerName -Namespace root/hp/instrumentedBIOS -Class hp_biosEnumeration
    $value = $BIOS | Select-Object Name, currentvalue
    $TPMBIOS = $value.currentvalue -eq $currentvalue
    if ($TPMBIOS -eq $false) {
        write-Host "$computerName : En cours - Modification du paramètre BIOS $name"
        set-setingBIOS -name $name -currentvalue $currentvalue
    }else {
        write-Host "$computerName : Succès - le paramètre BIOS $name est déjà configuré"
    }
}
# ! Set-SetingBIOS
# * la fonction se lance après Get-SetingBIOS si le paramètre BIOS $currentvalue n'est pas bien configuré
# * la fonction modifiera le paramètre correctement
# * si la fonction réussie l'ordinateur redémarra
# * en cas d'erreur le script s'arrêtera
# ? comment lancer la fonction Get-SetingBIOS
# ? Set-setingBIOS -name "[nom paramettre BIOS]" -currentvalue "[Nom de la valeur]"
function Set-SetingBIOS {
    param (
        $name,
        $currentvalue
    )

    $Interface = Get-WmiObject -computername $computerName -Namespace root/hp/InstrumentedBIOS -Class HP_BIOSSettingInterface
    $MDP_BIOS_UTF16 = "<utf-16/>"+$MDP_BIOS
    
    $Execute_Change_Action = $Interface.SetBIOSSetting($name,$currentvalue,$MDP_BIOS_UTF16)
    $Execute_Change_Action_Return = $Execute_Change_Action
    if (($Execute_Change_Action_Return)) {
        write-Host "$computerName : Succès - Modification du paramètre BIOS $name avec succès en $currentvalue"
    }else {
        write-Host "$computerName : Erreur - Impossible de modifier le paramètre BIOS $name en $currentvalue"
        Exit
    }

}

# ! Get-TMPStatus
# * Vérification du status de la puce TMP
# * si la puce n'est pas activer la fonction Set-ActiveTMP sera lancer
function Get-TMPStatus {
    try {
        $TPM = Invoke-Command -ComputerName $computerName -ScriptBlock {
            (Get-Tpm).TpmReady
        }
        if ($TPM -eq $false) {
            write-Host "$computerName : En cours - Activation de la PUCE TMP"
            Set-ActiveTMP
        }else {
            write-Host "$computerName : Succès - Puce TMP était déjà activée"
        }
    }catch{
        write-Host "$computerName : Erreur - Une erreur est survenue lors de l'exécution de la fonction Get-TMPStatus"
        Exit    
    }
    
}
# ! Set-ActiveTMP
# * Activation de la puce TMP
# * en cas d'erreur le script s'arretera
function Set-ActiveTMP {
    Invoke-Command -ComputerName $computerName -ScriptBlock {
        Initialize-Tpm -AllowClear -AllowPhysicalPresence
    }
    if ($? -eq $true) {
        write-Host "$computerName : Succès - La Puce TMP viens d'être activer"
    }else {
        write-Host "$computerName : Erreur - La Puce TMP n'a pas été activer"
        Exit
    }
}
# ! Convert-MBRTOGPT
# * si le disque dur est en MBR alors la fonction modifiera le format du disque dur C: en GPT
# * en cas d'erreur il désactivera le scriptage du disque C: pour résoudre les problèmes liés à l'installation de BitLocker en échec
# * 2ème tentative pour modifier le disque dur C: en GPT
# * si la fonction réussie l'ordinateur redémarra puis supprimera la partition D créés lors de la conversion
# * en cas d'erreur apres la 2 ème t'entative la fontion  s'arretera 
function Convert-MBRTOGPT {
    try {
        $disk = Invoke-Command -ComputerName $computerName -ScriptBlock {
            (Get-Disk -Number 0).PartitionStyle
        }
        if ( $disk -eq 'MBR') {
            Invoke-Command -ComputerName $computerName -ScriptBlock {
                mbr2gpt.exe /convert /disk:0 /allowFullOS
            }
            if ($? -eq $true) {
                write-Host "$computerName : Succès - Le disque C: est passé de MBR à GPT avec succès"
                Start-Reboot
                Remove-Volume
            }else {
                write-Host "$computerName : En cours - une erreur est survenue lors de la modification du format du disque C: une 2ème tentative va être essayée"
                write-Host "$computerName : En cours - désactivation du chiffrement Bitlocker"
                Invoke-Command -ComputerName $computerName -ScriptBlock {
                    manage-bde -off C:
                    mbr2gpt.exe /convert /disk:0 /allowFullOS
                }
                if ($? -eq $true) {
                    write-Host "$computerName : Succès - Le disque C: est passé de MBR à GPT avec succès"
                    Start-Reboot
                    Remove-Volume
                }else {
                    write-Host "$computerName : Erreur - Le disque C: n'a pas réussi à passer en GPT"
                    Exit
                }
            }
        }else {
            write-Host "$computerName : Succès - Le disque C: été déjà en GPT"
        }
    }catch{
        write-Host "$computerName : Erreur - Une erreur est survenue lors de l'exécution de la fonction Convert-MBRTOGPT"
        Exit    
    }
}
# ! Remove-Volume
# * fonction appelée par Convert-MBRTOGPT pour supprimer la partition D créée après la conversion du forma MBR vers GPT
# * en cas d'erreur le script s'arretera
function Remove-Volume {
    try {
        $volume = Invoke-Command -ComputerName $computerName -ScriptBlock {
            (Get-Volume).DriveLetter
        }

        if ($volume -eq "D") {
            Invoke-Command -ComputerName $computerName -ScriptBlock {
                Remove-Partition -DriveLetter "D" -Confirm:$false
            }
            if ($? -eq $true) {
                write-Host "$computerName : Succès - la Partition D à été supprimer avec succès"
            }else {
                write-Host "$computerName : Erreur - la Partition D n'a pas réussi a etre supprimer"
                Exit
            }
        }else {
            write-Host "$computerName : Succès - la Partition D n'est pas présente"
        }
    }catch{
        write-Host "$computerName : Erreur - Une erreur est survenue lors de l'exécution de la fonction Convert-MBRTOGPT"
        Exit    
    }
}
# ! Start-Reboot
# * Redémmare l'ordinateur puis attende qu'il ait redémarré
# * si l'ordinateur n'a pas réussi à redémarrer en 5 min le script se stop pour ne pas le bloquer
function Start-Reboot {
    Restart-Computer -ComputerName $computerName -Force -Wait -For PowerShell -Timeout 500 -Delay 2
    if ($?){
        write-Host "$computerName : Succès - l'ordinateur a redémarré avec succès"
        Start-Sleep -Seconds 15    
    }else{
        write-Host "$computerName : Erreur - l'ordinateur n'a pas réussi à redémarrer"
        Exit
    }
}

# ! main
function main {
    $ErrorActionPreference = 'SilentlyContinue' # ignore les erreur pour l'affichage, (le script les gère deja)
    write-Host ""
    Get-rightAdmin
    Get-PingStatus
    Get-BitLockerStatus
    Get-setingBIOS -name "TPM Activation Policy" -currentvalue "No prompts"
    Get-setingBIOS -name "TPM Device" -currentvalue "Available"
    Get-setingBIOS -name "TPM State" -currentvalue "Enable"
    Get-setingBIOS -name "UEFI Boot Options" -currentvalue "Enable"
    Start-Reboot
    Get-TMPStatus
    Convert-MBRTOGPT
    write-Host "$computerName : Succès - BitLocker est prêt à être installé sur le l'ordinateur"
}

main