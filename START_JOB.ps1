if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    #  * Lien vers la liste PC changer le chemin en fonction de vos besoins
    <#
    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.BrowseForFolder( 0, 'Select a folder to proceed', 16, $shell.NameSpace( 17 ).Self.Path ).Self.Path
    
    if ($folder -eq $null) {
        Read-Host -ForegroundColor red "tu a pas choisi de dossier relance le script"
        pause
    }
    #>

    $folder = "[your_script_folder]"
    Set-Location $folder
    $file_Excel = ".\Liste_PC.csv"

    # * Lien vers le script "Prerequis_Bitlocker.ps1" changer le chemin en fonction de vos besoins
    $script = $folder +".\Prerequis_Bitlocker.ps1"
    # * mot de passe BIOS
    $MDP_BIOS = "[your_password_BIOS_HP]"
    Import-Csv $file_Excel | ForEach-Object {
        $PC = $($_.PC)
        # * appelle script "Prerequis_Bitlocker.ps1" avec comme parametre -computerName $PC -password $BIOS_password création des JOb 
        Start-Job -ScriptBlock {
            PowerShell.exe -Command $args[0] -computerName $args[1] -MDP_BIOS $args[2]
        } -ArgumentList $script, $PC, $MDP_BIOS
    }
    
    Get-date
    write-Host "le script est en cours d'execution"
    # * attendre les Jobs
    Get-Job | Wait-Job -Timeout 2000
    # * affiche les Jobs
    Get-Job | Receive-Job | Out-GridView
}
else {
    Write-Host -ForegroundColor red "vous n'aviez pas les droits pour exécuter ce script"
}