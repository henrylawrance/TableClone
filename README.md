# Copy-Table.ps1 #
* Clone a single table from Banner to a MSSQL server. Will create table if necessary with structure from Oracle. 
* Performs full refresh of data. 
* Dates convert to VARCHAR plain text.
* SourceTableName must be provided in all caps. 
* Use -OverwriteExisting switch to delete data and refresh in an existing table. 
* Use -RunOutput to execute SQL script at end. Otherwise, output will be saved to be run later
* Use -OutputFile "$(Get-date -f 'MMddyy')_update.sql" to generate a daily SQL file
* Use -LogFile to define a specific error log location
---
### EXAMPLE 1 ###
```Copy-Table -SourceTableName SOURCE -DestinationTableName DEST -DestinationDatabaseName TestData -DestinationServerName sql2014 -RunOutput -OverwriteExisting```
> Copy table, overwriting any existing data, execute on SQL server
### EXAMPLE 2 ###    
```Copy-Table -SourceTableName SOURCE -DestinationTableName DEST -DestinationDatabaseName TestData -DestinationServerName sql2014 -RunOutput```
> Create new table but do not overwrite, copy data over,  execute on SQL server
### EXAMPLE 3 ###
```Copy-Table -SourceTableName SOURCE -DestinationTableName DEST -OutputFile "$(Get-date -f 'MMddyy')_update.sql" -OverwriteExisting -RunOutput```
> Create or update table, copy and overwrite data, create file of the day to be stored, run output.
### EXAMPLE 4 ###
```Copy-Table -SourceTableName SOURCE -DestinationTableName DEST -RowLimit 50 -RunOutput```
> Create table, limit data to 50 rows, run output
