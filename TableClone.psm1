$global:VerbosePreference = "Continue"
Set-Location (Split-Path $MyInvocation.MyCommand.Path)

Add-type -Path "C:\oracle\instantclient_10_2\odp.net\managed\common\Oracle.ManagedDataAccess.dll"
$Oracle_Credential_Path = ".\private\oracred.xml"
$global:Oracle_Cred = Import-Clixml -Path $Oracle_Credential_Path

$functionFolders = @('functions')
ForEach ($folder in $functionFolders) {
    $folderPath = Join-Path -Path $PSScriptRoot -ChildPath $folder
    If (Test-Path -Path $folderPath) {
        Write-Verbose -Message "Importing from $folder"
        $functions = Get-ChildItem -Path $folderPath -Filter '*.ps1'
        ForEach ($function in $functions) {
            Write-Verbose -Message "  Importing $($function.BaseName)"
            . $function.FullName
        }
    }
}
Export-ModuleMember *