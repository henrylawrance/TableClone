Import-Module ./modules/invoke-oracmd.psm1
function Global:Copy-Table {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory=$true)][String] $SourceTableName,
        [parameter(Mandatory=$true)][String] $DestinationTableName,
        [parameter(Mandatory=$false)][String] $DestinationDatabaseName = "OUDATA",
        [parameter(Mandatory=$false)][String] $DestinationServerName = "ocsql2014",
        [parameter(Mandatory=$false)][Switch] $OverwriteExisting = $false,
        [parameter(Mandatory=$false)][Switch] $RunOutput = $false,
        [parameter(Mandatory=$false)][String] $OutputFile = "output.sql"

    )
    if(Test-Path $OutputFile) {
        Remove-Item $OutputFile
    }
    $Columns = (Invoke-Oracmd -Query "select COLUMN_NAME,DATA_TYPE,DATA_LENGTH,NULLABLE from all_tab_columns where table_name = '$($SourceTableName)'" -Prod -OutputDataSet).Tables
    if($Columns.COLUMN_NAME.count -eq 0) { "Table Name does not exist in Oracle (Check Capitalization)"; Return }
    $OraData = Invoke-Oracmd -Query "select * from $($SourceTableName) where rownum <= 500" -Prod -OutputDataSet
    $TableCheck = Invoke-Sqlcmd -Query "select * from sys.tables where name = '$($DestinationTableName)'" -ServerInstance $DestinationServerName -Database $DestinationDatabaseName
    if($TableCheck.name.count -eq 0) {   
        $CreateQuery = "CREATE TABLE [dbo].[$DestinationTableName](`n"
        Foreach($Column in $Columns) {
            $data_type = switch($Column.DATA_TYPE) {
                "NUMBER" { "VARCHAR" }
                "VARCHAR2" { "VARCHAR" }
                "DATE" { "VARCHAR" }
                default { $Column.DATA_TYPE }
            }
            $data_length = switch($Column.DATA_TYPE) {
                "DATE" { 50 }
                default { $Column.DATA_LENGTH }
            }
            $null_type = switch($Column.NULLABLE) {
                "N" { "NOT NULL" }
                default { "NULL" }
            }

            $CreateQuery += "`t[$($Column.COLUMN_NAME)] [$($data_type)] ($($data_length)) $null_type"
            if(([array]::IndexOf($Columns.COLUMN_NAME, $Column.COLUMN_NAME))+1 -lt $Columns.COLUMN_NAME.Count) {
                $CreateQuery += ",`n"
            } else {
                $CreateQuery += "`n"
            }
        }
        $CreateQuery += ")"

        $CreateQuery | out-file -enc ascii $OutputFile -Append
    } else {
        if($OverwriteExisting.IsPresent) {
            $DeleteQuery = "TRUNCATE TABLE $($DestinationTableName)"
            $DeleteQuery | out-file -enc ascii $OutputFile -Append
        } else {
            "Table already exists. Use -OverwriteExisting switch to override"; Return
        }
    }

    
    ForEach($Line in $OraData.Tables) {
        $InsertQuery = "INSERT INTO $($DestinationTableName) ("
        $InsertQuery += $Columns.COLUMN_NAME -join ","
        $InsertQuery += ")`n`tVALUES ("
        foreach($Column_Name in $Columns.COLUMN_NAME) {
            $value = $Line[$Column_Name]
            $b_value = switch($value.GetType().Name) {
                "String" { $value.replace("'","''") }
                default { $value }
            }
            $InsertQuery += "`'$b_value`'"
            if(([array]::IndexOf($Columns.COLUMN_NAME, $Column_Name))+1 -lt $Columns.COLUMN_NAME.Count) {
                $InsertQuery += ","
            }
        }
        $InsertQuery += ")"
        $InsertQuery | out-file -enc ascii $OutputFile -Append
        
    }

    switch($RunOutput.IsPresent) {
        $true { Invoke-Sqlcmd -InputFile .\output.sql -ServerInstance $DestinationServerName -Database $DestinationDatabaseName | out-file -FilePath .\log.rpt }
    }
    
}
#Copy-Table -SourceTableName GZRADUS -DestinationTableName GZRADUS -DestinationDatabaseName OUTestData -DestinationServerName ocsql2014