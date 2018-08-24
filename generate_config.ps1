if(-not(Test-Path .\private)){
    Write-Verbose "Creating .\private diretory"
    New-Item -Path .\private -ItemType directory
}

if(Test-Path .\private\oracred.xml) {
    $overwrite = switch (Read-Host -Prompt "oracred.xml exists. Create new? [Y/N]") {
        { $_ -match 'Y|y' } { $true }
        default {$false}
    }
}
if($overwrite -or -not(Test-Path .\private\oracred.xml)) {
    Write-Verbose "Generating fresh oracred.xml file. Please enter Oracle Credentials"
    $Oracle_Credential_Path = ".\private\oracred.xml"

    # Oracle Credential File
    Get-Credential | Export-Clixml -Path $Oracle_Credential_Path
}
