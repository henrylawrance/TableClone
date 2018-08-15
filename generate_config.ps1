
$Oracle_Credential_Path = ".\private\oracred.xml"

# Oracle Credential File
Get-Credential | Export-Clixml -Path $Oracle_Credential_Path
