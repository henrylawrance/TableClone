Add-type -Path "C:\oracle\instantclient_10_2\odp.net\managed\common\Oracle.ManagedDataAccess.dll"
function Invoke-Oracmd {
    Param(
    [parameter(Mandatory=$true,Position=0)][String] $Query,
    [parameter(Mandatory=$false)][switch] $Test,
    [parameter(Mandatory=$false)][switch] $Prod,
    [parameter(Mandatory=$false)][switch] $OutputDataSet
    )
    
    if($Test.IsPresent) {
        $tns="Data Source= (DESCRIPTION =(ADDRESS =(PROTOCOL = TCP)(HOST = 205.133.226.85)(PORT = 8002))(CONNECT_DATA =(SERVICE_NAME = TEST.ottu.edu)));User Id=ouautomation;Password=fhpD0vO8;"
    } elseif ($Prod.IsPresent) {
        $tns="Data Source= (DESCRIPTION =(ADDRESS =(PROTOCOL = TCP)(HOST = 205.133.226.84)(PORT = 8002))(CONNECT_DATA =(SERVICE_NAME = PROD.ottu.edu)));User Id=ouautomation;Password=fhpD0vO8;"
    } else {
        Write-Error "Prod or Test not specified. Use -Test or -Prod."
    }
    $con = New-Object Oracle.ManagedDataAccess.Client.OracleConnection($tns)
	$con.open()
	$command=$con.CreateCommand()
	$command.CommandText=$Query 
	$da=New-Object Oracle.ManagedDataAccess.Client.OracleDataAdapter($command)
	$BanUsers = @()
	$BanUsers = New-Object System.Data.DataSet 
	$da.fill($BanUsers)
	$con.Close()
    if($OutputDataSet.IsPresent) {
        $BanUsers
    } else {
	    $BanUsers.Tables[0]
    }
}

Export-ModuleMember -Function *