REM Replace database and schema to match your case
snowsql ^
--config ..\config\.snowsql\config ^
-f .\schedule2_data_aggregator_test.sql ^
-o exit_on_error=true ^
-o quiet=true ^
-o friendly=true ^
-D db_name=BI_TEST ^
-D sc_name=CONTRL_LOGIC