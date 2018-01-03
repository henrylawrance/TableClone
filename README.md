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
### EXAMPLE ###
```Copy-Table -SourceTableName GZRADUS -DestinationTableName GZRADUS -DestinationDatabaseName OUTestData -DestinationServerName ocsql2014 -RunOutput -OverwriteExisting```
> Copy table, overwriting any existing data, execute on SQL server
---
### EXAMPLE ###    
```Copy-Table -SourceTableName GZRADUS -DestinationTableName TEMPTABLE -DestinationDatabaseName OUData -DestinationServerName ocsql2014 -RunOutput```
> Create new table but do not overwrite, copy data over,  execute on SQL server
---
### EXAMPLE ###
```Copy-Table -SourceTableName GZRADUS -DestinationTableName TEMPTABLE -OutputFile "$(Get-date -f 'MMddyy')_update.sql" -OverwriteExisting -RunOutput```
> Create or update table, copy and overwrite data, create file of the day to be stored, run output.
---
### EXAMPLE ###
```Copy-Table -SourceTableName GZRADUS -DestinationTableName TEMPTABLE -RowLimit 50 -RunOutput```
> Create table, limit data to 50 rows, run output