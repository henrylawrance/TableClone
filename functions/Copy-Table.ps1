function Copy-Table {
    <#
.SYNOPSIS
    Clone a single table from Banner to a MSSQL server. Will create table if necessary with structure from Oracle. 
    Performs full refresh of data. 
    Dates convert to VARCHAR plain text.
    SourceTableName must be provided in all caps. 
    Use -OverwriteExisting switch to delete data and refresh in an existing table. 
    Use -RunOutput to execute SQL script at end. Otherwise, output will be saved to be run later
    Use -OutputFile "$(Get-date -f 'MMddyy')_update.sql" to generate a daily SQL file
    Use -LogFile to define a specific error log location
.EXAMPLE
    Copy-Table -SourceTableName GZRADUS -DestinationTableName GZRADUS -DestinationDatabaseName OUTestData -DestinationServerName ocsql2014 -RunOutput -OverwriteExisting
        - Copy table, overwriting any existing data, execute on SQL server
.EXAMPLE        
    Copy-Table -SourceTableName GZRADUS -DestinationTableName TEMPTABLE -DestinationDatabaseName OUData -DestinationServerName ocsql2014 -RunOutput
        - Create new table but do not overwrite, copy data over,  execute on SQL server
.EXAMPLE
    Copy-Table -SourceTableName GZRADUS -DestinationTableName TEMPTABLE -OutputFile "$(Get-date -f 'MMddyy')_update.sql" -OverwriteExisting -RunOutput
        - Create or update table, copy and overwrite data, create file of the day to be stored, run output.
.EXAMPLE
    Copy-Table -SourceTableName GZRADUS -DestinationTableName TEMPTABLE -RowLimit 50 -RunOutput
        - Create table, limit data to 50 rows, run output

#>
    [CmdletBinding()]
    Param(
        [parameter(Mandatory)][String] $SourceTableName,
        [parameter(Mandatory)][String] $DestinationTableName,
        [parameter(Mandatory)][String] $DestinationDatabaseName,
        [parameter(Mandatory)][String] $DestinationServerName,
        [parameter()][Switch] $OverwriteExisting,
        [parameter()][Switch] $RunOutput,
        [parameter()][String] $OutputFile = ".\output.sql",
        [parameter()][String] $LogFile = ".\log.rpt",
        [parameter()][Int] $RowLimit

    )
    # Remove old Output File (include the date in the output name if you want to save these, see example 3)
    if (Test-Path $OutputFile) {
        Write-Verbose "REMOVING OLD $OutputFile"
        Remove-Item $OutputFile
    }
    # Get Table Info from Oracle
    $Columns = (Invoke-Oracmd -Query "select COLUMN_NAME,DATA_TYPE,DATA_LENGTH,NULLABLE from all_tab_columns where table_name = '$($SourceTableName)'" -OutputDataSet -ServerAddress 205.133.226.84 -ServiceName PROD.ottu.edu -Cred $Oracle_Cred).Tables
    # Verify Table Exists in Banner
    if ($Columns.COLUMN_NAME.count -eq 0) { Write-Warning "SourceTableName does not exist in Oracle (Check Capitalization)"; Return }
    # Allow limiting of Rows for testing
    if ($RowLimit) {
        Write-Warning "ROWS LIMITED TO $RowLimit"
        $OraData = Invoke-Oracmd -Query "select * from $($SourceTableName) where rownum <= $RowLimit" -OutputDataSet -ServerAddress 205.133.226.84 -ServiceName PROD.ottu.edu -Cred $Oracle_Cred
    }
    else {
        $OraData = Invoke-Oracmd -Query "select * from $($SourceTableName)" -OutputDataSet -ServerAddress 205.133.226.84 -ServiceName PROD.ottu.edu -Cred $Oracle_Cred
    }
    # Check if table exists in SQL
    $TableCheck = Invoke-Sqlcmd -Query "select * from sys.tables where name = '$($DestinationTableName)'" -ServerInstance $DestinationServerName -Database $DestinationDatabaseName
    if ($TableCheck.name.count -eq 0) { 
        # If it doesn't exist, create it
        Write-Verbose "CREATE TABLE [dbo].[$DestinationTableName]" 
        $CreateQuery = "CREATE TABLE [dbo].[$DestinationTableName](`n"
        Foreach ($Column in $Columns) {
            $data_type = switch ($Column.DATA_TYPE) {
                "NUMBER" { "VARCHAR" }
                "VARCHAR2" { "VARCHAR" }
                "DATE" { "VARCHAR" }
                default { $Column.DATA_TYPE }
            }
            $data_length = switch ($Column.DATA_TYPE) {
                "DATE" { 50 }
                default { $Column.DATA_LENGTH }
            }
            $null_type = switch ($Column.NULLABLE) {
                "N" { "NOT NULL" }
                default { "NULL" }
            }

            $CreateQuery += "`t[$($Column.COLUMN_NAME)] [$($data_type)] ($($data_length)) $null_type"
            if (([array]::IndexOf($Columns.COLUMN_NAME, $Column.COLUMN_NAME)) + 1 -lt $Columns.COLUMN_NAME.Count) {
                $CreateQuery += ",`n"
            }
            else {
                $CreateQuery += "`n"
            }
        }
        $CreateQuery += ")"

        $CreateQuery | out-file -enc ascii $OutputFile -Append
    }
    else {
        # Table already exists, check flag to continue or not
        if ($OverwriteExisting.IsPresent) {
            # Delete all the data if flag is set
            Write-Verbose "TRUNCATE TABLE [dbo].[$DestinationTableName]"
            $DeleteQuery = "TRUNCATE TABLE [dbo].[$DestinationTableName]"
            $DeleteQuery | out-file -enc ascii $OutputFile -Append
        }
        else {
            Write-Warning "Table already exists. Use -OverwriteExisting switch to override"; Return
        }
    }

    # Build Inserts for pushing data
    Write-Verbose "GENERATING INSERTS INTO [dbo].[$DestinationTableName]"
    ForEach ($Line in $OraData.Tables) {
        $InsertQuery = "INSERT INTO [dbo].[$DestinationTableName] ("
        $InsertQuery += $Columns.COLUMN_NAME -join ","
        $InsertQuery += ")`n`tVALUES ("
        foreach ($Column_Name in $Columns.COLUMN_NAME) {
            # Replace apostrophes in names with escaped apostrophe
            $value = switch ($($Line[$Column_Name]).GetType().Name) {
                "String" { $($Line[$Column_Name]).replace("'", "''") }
                default { $Line[$Column_Name] }
            }
            $InsertQuery += "`'$($value)`'"
            if (([array]::IndexOf($Columns.COLUMN_NAME, $Column_Name)) + 1 -lt $Columns.COLUMN_NAME.Count) {
                $InsertQuery += ","
            }
        }
        $InsertQuery += ")"
        $InsertQuery | out-file -enc ascii $OutputFile -Append
        
    }
    # Check for RunOutput flag, run if set
    switch ($RunOutput.IsPresent) {
        $true {
            Write-Verbose "EXECUTING $OutputFile on $DestinationServerName" 
            Invoke-Sqlcmd -InputFile $OutputFile -ServerInstance $DestinationServerName -Database $DestinationDatabaseName | out-file -FilePath $LogFile -Append 
        }
    }
    
}
