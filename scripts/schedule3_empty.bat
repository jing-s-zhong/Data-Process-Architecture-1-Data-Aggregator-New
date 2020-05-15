rem ====================================================
rem Schedule-3: Empty the DATA_AGGREGATOR
rem ----------------------------------------------------
rem Example: schedule3_empty.bat BI_TEST DATA_AGGREGATOR
rem ====================================================
@echo off
if [%1]==[] goto missDb
if [%2]==[] goto missSchema

@echo Enptying the test data of the data aggregator in %1.%2
snowsql ^
--config ..\..\config\.snowsql\config ^
-f .\schedule3_empty.sql ^
-o exit_on_error=true ^
-o quiet=true ^
-o friendly=true ^
-D db_name=%1 ^
-D sc_name=%2
@echo The data aggregator is emptyed the test data in %1.%2
goto done

:missDb
@echo First argument for DB name is missing!
goto done

:missSchema
@echo Second argument for SCHEMA name is missing!

:done