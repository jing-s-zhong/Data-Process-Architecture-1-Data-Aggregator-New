REM Replace database and schema to match your case
snowsql ^
--config ..\config\.snowsql\config ^
-f .\schedule5_data_aggregator_remove.sql ^
-o exit_on_error=true ^
-o quiet=true ^
-o friendly=true ^
-D db_name=BI_TEST ^
-D sc_name=CONTRL_LOGIC