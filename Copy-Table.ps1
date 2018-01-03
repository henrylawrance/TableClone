Import-Module ./modules/invoke-oracmd.psm1
function Global:Copy-Table {
<#
.SYNOPSIS
    Clone a single table from Banner to a MSSQL server. Will create table if necessary with structure from Oracle. 
    Performs full refresh of data. 
    Dates convert to VARCHAR plain text.
    SourceTableName must be provided in all caps. 
    Use -OverwriteExisting switch to delete data and refresh in an existing table. 
    Use -RunOutput to execute SQL script at end. Otherwise, output will be saved to be run later
.EXAMPLE
    Copy-Table -SourceTableName GZRADUS -DestinationTableName GZRADUS -DestinationDatabaseName OUTestData -DestinationServerName ocsql2014 -RunOutput -OverwriteExisting
        - Copy table, overwriting any existing data, execute on SQL server
.EXAMPLE        
    Copy-Table -SourceTableName GZRADUS -DestinationTableName TEMPTABLE -DestinationDatabaseName OUData -DestinationServerName ocsql2014 -RunOutput
        - Create new table but do not overwrite, copy data over,  execute on SQL server
.EXAMPLE
    Copy-Table -SourceTableName GZRADUS -DestinationTableName TEMPTABLE -OutputFile "$(Get-date -f 'MMddyy')_update.sql" -OverwriteExisting -RunOutput
        - Create or update table, copy and overwrite data, create file of the day to be stored, run output.

#>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory=$true)][String] $SourceTableName,
        [parameter(Mandatory=$true)][String] $DestinationTableName,
        [parameter(Mandatory=$false)][String] $DestinationDatabaseName = "OUDATA",
        [parameter(Mandatory=$false)][String] $DestinationServerName = "ocsql2014",
        [parameter(Mandatory=$false)][Switch] $OverwriteExisting = $false,
        [parameter(Mandatory=$false)][Switch] $RunOutput = $false,
        [parameter(Mandatory=$false)][String] $OutputFile = ".\output.sql"

    )
    if(Test-Path $OutputFile) {
        Remove-Item $OutputFile
    }
    $Columns = (Invoke-Oracmd -Query "select COLUMN_NAME,DATA_TYPE,DATA_LENGTH,NULLABLE from all_tab_columns where table_name = '$($SourceTableName)'" -Prod -OutputDataSet).Tables
    if($Columns.COLUMN_NAME.count -eq 0) { Write-Warning "SourceTableName does not exist in Oracle (Check Capitalization)"; Return }
    $OraData = Invoke-Oracmd -Query "select * from $($SourceTableName) where rownum <= 500" -Prod -OutputDataSet
    $TableCheck = Invoke-Sqlcmd -Query "select * from sys.tables where name = '$($DestinationTableName)'" -ServerInstance $DestinationServerName -Database $DestinationDatabaseName
    if($TableCheck.name.count -eq 0) { 
        Write-Verbose "CREATE TABLE [dbo].[$DestinationTableName]" 
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
            Write-Verbose "TRUNCATE TABLE $($DestinationTableName)"
            $DeleteQuery = "TRUNCATE TABLE $($DestinationTableName)"
            $DeleteQuery | out-file -enc ascii $OutputFile -Append
        } else {
            Write-Warning "Table already exists. Use -OverwriteExisting switch to override"; Return
        }
    }

    Write-Verbose "GENERATING INSERTS"
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
        $true {
            Write-Verbose "EXECUTING $OutputFile" 
            Invoke-Sqlcmd -InputFile $OutputFile -ServerInstance $DestinationServerName -Database $DestinationDatabaseName | out-file -FilePath .\log.rpt -Append }
    }
    
}
