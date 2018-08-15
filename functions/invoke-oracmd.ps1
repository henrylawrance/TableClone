
function Invoke-Oracmd {
    Param(
        [parameter(Mandatory)][String] $Query,
        [parameter()][String] $ServerAddress = $Oracle_ServerAddress,
        [parameter()][String] $Port = '8002',
        [parameter()][String] $Protocol = 'TCP',
        [parameter()][String] $ServiceName = $Oracle_ServiceName,
        [parameter()][pscredential] $Cred = $Oracle_Cred,
        [parameter()][switch] $OutputDataSet

    )
    begin {
        try {
            $Username = $Cred.UserName
            $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Cred.Password))
        }
        catch {
            Write-Error "Credential Error"
            throw
        }
        $tns = "Data Source= (DESCRIPTION =(ADDRESS =(PROTOCOL = $Protocol)(HOST = $ServerAddress)(PORT = $Port))(CONNECT_DATA =(SERVICE_NAME = $ServiceName)));User Id=$Username;Password=$Password;"
        try {
            $con = New-Object Oracle.ManagedDataAccess.Client.OracleConnection($tns)
            $con.open()
        }
        catch {
            Write-Error "Error Connecting to $($ServerAddress):$Port ($Protocol)"
            throw
        }

    }
    process {
        try {
            $command = $con.CreateCommand()
            $command.CommandText = $Query
            $da = New-Object Oracle.ManagedDataAccess.Client.OracleDataAdapter($command)
            $output = @()
            $output = New-Object System.Data.DataSet
            $da.fill($output)
        }
        catch {
            Write-Error "Error Executing Query: $Query"
        }
    }
    end {
        try {
            $con.Close()
            if ($OutputDataSet.IsPresent) {
                $output
            }
            else {
                $output.Tables[0]
            }
        }
        catch {
            Write-Error "Error producing output"
        }
    }
}
