!set variable_substitution=true;
!define ver=V20;
--
use database &{db_name};
create schema if not exists &{sc_name};
--create schema &{sc_name};
use schema &{sc_name};
--
ALTER TABLE IF EXISTS DATA_AGGREGATION_TARGETS RENAME TO _BKBY_&{ver}_DATA_AGGREGATION_TARGETS;
ALTER TABLE IF EXISTS DATA_AGGREGATION_SOURCES RENAME TO _BKBY_&{ver}_DATA_AGGREGATION_SOURCES;
ALTER TABLE IF EXISTS DATA_AGGREGATION_LOGGING RENAME TO _BKBY_&{ver}_DATA_AGGREGATION_LOGGING;
ALTER FUNCTION IF EXISTS DATA_PATTERN(ARRAY) RENAME TO _BKBY_&{ver}_DATA_PATTERN;
ALTER FUNCTION IF EXISTS COLUMN_MAP(ARRAY) RENAME TO _BKBY_&{ver}_COLUMN_MAP;
ALTER FUNCTION IF EXISTS REVENUE_SHARE(VARIANT, VARCHAR, FLOAT) RENAME TO _BKBY_&{ver}_REVENUE_SHARE;
ALTER FUNCTION IF EXISTS REVENUE_SHARE(VARIANT, VARCHAR) RENAME TO _BKBY_&{ver}_REVENUE_SHARE;
ALTER PROCEDURE IF EXISTS DATA_AGGREGATOR(VARCHAR, BOOLEAN, BOOLEAN, BOOLEAN, VARCHAR) RENAME TO _BKBY_&{ver}_DATA_AGGREGATOR;
ALTER PROCEDURE IF EXISTS DATA_AGGREGATOR(VARCHAR, BOOLEAN, BOOLEAN) RENAME TO _BKBY_&{ver}_DATA_AGGREGATOR;
--
-------------------------------------------------------
-- Create task management tables
-------------------------------------------------------
--
-- DROP SEQUENCE DATA_AGGREGATION_TARGETS_SEQ;
--
--CREATE SEQUENCE DATA_AGGREGATION_TARGETS_SEQ START = 1 INCREMENT = 1;
--
-- DROP TABLE DATA_AGGREGATION_TARGETS;
--
CREATE TABLE DATA_AGGREGATION_TARGETS
(
	TARGET_ID 					NUMBER NOT NULL DEFAULT DATA_AGGREGATION_TARGETS_SEQ.NEXTVAL,
	TARGET_LABEL				TEXT,
	TARGET_DATA					TEXT NOT NULL,
	BATCH_CONTROL_COLUMN		TEXT,
	BATCH_CONTROL_SIZE			NUMBER,
	BATCH_CONTROL_NEXT			TEXT,
	BATCH_PROCESSED		    	TIMESTAMP_NTZ,
	BATCH_PROCESSING			TIMESTAMP_NTZ,
	BATCH_MICROCHUNK_CURRENT 	TIMESTAMP_NTZ,
	BATCH_SCHEDULE_TYPE			TEXT,
	BATCH_SCHEDULE_LAST			TIMESTAMP_NTZ,
	PATTERN_COLUMNS		    	ARRAY,
	GROUPBY_COLUMNS		    	ARRAY,
	GROUPBY_PATTERN		    	NUMBER,
	GROUPBY_FLEXIBLE			BOOLEAN,
	AGGREGATE_COLUMNS			ARRAY,
	AGGREGATE_FUNCTIONS			ARRAY,
	SUPPORT_SP_VERSIONS			ARRAY,
	CONSTRAINT PK_DATA_AGGREGATION_TARGETS PRIMARY KEY (TARGET_ID)
)
CLUSTER BY (TARGET_DATA)
COMMENT = 'This tableis used to register the aggregation targets'
;
INSERT INTO DATA_AGGREGATION_TARGETS (TARGET_ID
	,TARGET_LABEL
	,TARGET_DATA
	,BATCH_CONTROL_COLUMN
	,BATCH_CONTROL_SIZE
	,BATCH_CONTROL_NEXT
	,BATCH_PROCESSED
	,BATCH_PROCESSING
	,BATCH_MICROCHUNK_CURRENT
	,BATCH_SCHEDULE_TYPE
	,BATCH_SCHEDULE_LAST
	,PATTERN_COLUMNS
	,GROUPBY_COLUMNS
	,GROUPBY_PATTERN
	,GROUPBY_FLEXIBLE
	,AGGREGATE_COLUMNS
	,AGGREGATE_FUNCTIONS
	,SUPPORT_SP_VERSIONS
	)
SELECT ID TARGET_ID
	,TARGET_LABEL
	,TARGET_TABLE
	,BATCH_CONTROL_COLUMN
	,BATCH_CONTROL_SIZE
	,BATCH_CONTROL_NEXT
	,BATCH_PROCESSED
	,BATCH_PROCESSING
	,BATCH_MICROCHUNK_CURRENT
	,BATCH_SCHEDULE_TYPE
	,BATCH_SCHEDULE_LAST
	,PATTERN_COLUMNS
	,GROUPBY_COLUMNS
	,GROUPBY_PATTERN
	,GROUPBY_FLEXIBLE
	,AGGREGATE_COLUMNS
	,AGGREGATE_FUNCTIONS
	,ARRAY_CONSTRUCT('V20')
FROM _BKBY_&{ver}_DATA_AGGREGATION_TARGETS
;
--
-- DROP SEQUENCE DATA_AGGREGATION_SOURCES_SEQ;
--
--CREATE SEQUENCE DATA_AGGREGATION_SOURCES_SEQ START = 1 INCREMENT = 1;
--
-- DROP TABLE DATA_AGGREGATION_SOURCES;
--
CREATE TABLE DATA_AGGREGATION_SOURCES
(
	SOURCE_ID 					NUMBER NOT NULL DEFAULT DATA_AGGREGATION_SOURCES_SEQ.NEXTVAL,
	TARGET_ID	        		NUMBER NOT NULL,
	SOURCE_LABEL				TEXT,
	SOURCE_DATA	        		TEXT NOT NULL,
	SOURCE_ENABLED	        	BOOLEAN,
	SOURCE_READY_TIME	    	TIMESTAMP_NTZ,
	SOURCE_CHECK_TIME	    	TIMESTAMP_NTZ,
	SOURCE_CHECK_QUERY	        TEXT,
	PATTERN_DEFAULT	        	NUMBER,
	PATTERN_FLEXIBLE	    	BOOLEAN,
	TRANSFORMATION	        	TEXT,
	CONSTRAINT PK_DATA_AGGREGATION_SOURCES PRIMARY KEY (SOURCE_ID),
	CONSTRAINT FK_DATA_AGGREGATION_SOURCES_TARGET_DATA FOREIGN KEY (TARGET_ID)
		REFERENCES DATA_AGGREGATION_TARGETS(TARGET_ID)
)
CLUSTER BY (TARGET_ID, SOURCE_DATA)
COMMENT = 'This tableis used to register the aggregation sources'
;
INSERT INTO DATA_AGGREGATION_SOURCES (SOURCE_ID
	,TARGET_ID
	,SOURCE_LABEL
	,SOURCE_DATA
	,SOURCE_ENABLED
	,SOURCE_READY_TIME
	,SOURCE_CHECK_TIME
	,SOURCE_CHECK_QUERY
	,PATTERN_DEFAULT
	,PATTERN_FLEXIBLE
	,TRANSFORMATION
	)
SELECT A.ID SOURCE_ID
	,B.ID TARGET_ID
	,A.SOURCE_LABEL
	,A.SOURCE_TABLE
	,A.SOURCE_ENABLED
	,A.DATA_AVAILABLETIME
	,A.DATA_CHECKSCHEDULE
	,NULL SOURCE_CHECK_QUERY
	,A.PATTERN_DEFAULT
	,A.PATTERN_FLEXIBLE
	,A.TRANSFORMATION
FROM _BKBY_&{ver}_DATA_AGGREGATION_SOURCES A
JOIN _BKBY_&{ver}_DATA_AGGREGATION_TARGETS B
ON A.TARGET_TABLE = B.TARGET_TABLE
;
--
-- DROP SEQUENCE DATA_AGGREGATION_LOGGING_SEQ;
--
--CREATE SEQUENCE DATA_AGGREGATION_LOGGING_SEQ START = 1 INCREMENT = 1;
--
-- DROP TABLE DATA_AGGREGATION_LOGGING;
--
CREATE TABLE DATA_AGGREGATION_LOGGING
(
	EVENT_ID 					NUMBER NOT NULL DEFAULT DATA_AGGREGATION_LOGGING_SEQ.NEXTVAL,
	EVENT_TIME	    	        TIMESTAMP_NTZ DEFAULT TO_TIMESTAMP_NTZ(CURRENT_TIMESTAMP),
	EVENT_TARGET	        	TEXT,
	EVENT_SOURCE	        	TEXT,
	EVENT_STATUS				TEXT,
	EVENT_STATE					TEXT,
	EVENT_QUERY					TEXT
)
COMMENT = 'This tableis used to log the error of running the processing'
;
--
!set variable_substitution=false;
-------------------------------------------------------
-- Create assisstant functions
-------------------------------------------------------
--
-- DROP FUNCTION DATA_PATTERN(ARRAY);
--
CREATE FUNCTION DATA_PATTERN(
	P ARRAY
	)
RETURNS DOUBLE
LANGUAGE JAVASCRIPT
AS
$$
if (typeof P !== "undefined" || P !== null) {
	datPat = 0, misBit = 0;
	if (typeof P[0] === "object") {
		Q = P[0]["pattern_columns"];
		R = P[0]["groupby_columns"];
		if (typeof Q !== "undefined" || Q !== null || typeof R !== "undefined" || R !== null) {
			patLen = Q.length;
			for (i = 0; i < patLen; i++) {
				if (R.indexOf(Q[i]) !== -1) {
					misBit = 0;
				} else {
					misBit = 1;
				}
				datPat = 2 * datPat + misBit;
			}
		}
	} else {
		patLen = P.length;
		for (i = 0; i < patLen; i++) {
			if (P[i]) {
				misBit = 0;
			} else {
				misBit = 1;
			}
			datPat = 2 * datPat + misBit;
		}
	}
}
return datPat;
$$;
--
--
-- DROP FUNCTION COLUMN_MAP(ARRAY);
--
CREATE FUNCTION COLUMN_MAP(
	P ARRAY
	)
RETURNS VARIANT
LANGUAGE JAVASCRIPT
AS
$$
mapping = {};
if (P !== "undefined" || P !== null) {
	Q = P[0];
	if (Q["target_column_list"] !== "undefined" && typeof Q["target_column_list"] === "object"
		&& Q["source_column_list"] !== "undefined" && typeof Q["source_column_list"] === "object"
		&& Q["target_column_list"].length === Q["source_column_list"].length
	) {
		patLen = Q["target_column_list"].length;
		for (i = 0; i < patLen; i++) {
			mapping[Q["target_column_list"][i]] = Q["source_column_list"][i];
		}
	}
}
return mapping;
$$;
--
--
-- DROP FUNCTION REVENUE_SHARE(VARIANT, VARCHAR, FLOAT);
--
CREATE FUNCTION REVENUE_SHARE(
	P VARIANT,
	D VARCHAR,
	V FLOAT
	)
RETURNS FLOAT
LANGUAGE JAVASCRIPT
AS
$$
var rev_share = null, Q = D;
if (D) { Q = D.toUpperCase(); }
if (typeof P === "undefined") {
	rev_share = null;
}
else if (typeof P === "number") {
	rev_share = P;
}
else if (typeof P[0] === "object" && typeof V !== "undefined") {
	rev_share = P.filter(x => (x["RANGE_LOWER"] <= V && (!x["RANGE_UPPER"] || x["RANGE_UPPER"] > V)))[0]["REVENUE_SHARE"];
}
else if (typeof P === "object") {
	if (typeof P[Q] === "number") {
		rev_share = P[Q];
	}
	else if (typeof P[Q] === "undefined" && typeof P["(Others)"] === "undefined") {
		rev_share = P["(OTHERS)"];
	}
}
return rev_share;
$$;
--
--
-- DROP FUNCTION REVENUE_SHARE(VARIANT, VARCHAR);
--
CREATE FUNCTION REVENUE_SHARE(
	P VARIANT,
	D VARCHAR
	)
RETURNS FLOAT
LANGUAGE JAVASCRIPT
AS
$$
var rev_share = null, Q = D;
if (D) { Q = D.toLowerCase(); if (["phone", "smart phones"].includes(Q)) { Q = 'mobile' } }
if (typeof P === "undefined") {
	rev_share = null;
}
else if (typeof P === "number") {
	rev_share = P;
}
else if (typeof P === "object") {
	for (item in P) {
		if (P[item][Q] && typeof P[item][Q][0] === "number") {
			rev_share = P[item][Q][0];
			break;
		}
	}
	if (!rev_share) {
		for (item in P) {
			if (P[item]["other"] && typeof P[item]["other"][0] === "number") {
				rev_share = P[item]["other"][0];
				break;
			}
		}
	}
}
return rev_share;
$$;

-------------------------------------------------------
-- Create aggregator stored procedures
-------------------------------------------------------
--
-- Aggregate generation stored procedues for indivual source
-- DROP PROCEDURE DATA_AGGREGATOR(VARCHAR, BOOLEAN, BOOLEAN, BOOLEAN, VARCHAR);
CREATE PROCEDURE  DATA_AGGREGATOR (
	TARGET_DATA VARCHAR,
	SCRIPT_ONLY BOOLEAN,
	LOG_DETAILS BOOLEAN,
	NON_ENABLED BOOLEAN,
	BATCH_TIMETAG VARCHAR
	)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT STRICT
AS
$$
var sqlScript = '', pageBreaker = '';

var sourceQuery = `SELECT
	  d.TARGET_DATA,
	  d.BATCH_CONTROL_COLUMN,
	  d.BATCH_CONTROL_SIZE,
	  d.BATCH_CONTROL_NEXT,
	  d.PATTERN_COLUMNS,
	  d.GROUPBY_COLUMNS,
	  CASE WHEN GROUPBY_FLEXIBLE THEN BITOR(d.GROUPBY_PATTERN, s.PATTERN_DEFAULT) ELSE d.GROUPBY_PATTERN END GROUPBY_PATTERN,
	  d.GROUPBY_FLEXIBLE OR (d.GROUPBY_PATTERN = BITOR(d.GROUPBY_PATTERN, s.PATTERN_DEFAULT)) GROUPBY_COMPITABLE,
	  d.GROUPBY_FLEXIBLE AND s.PATTERN_FLEXIBLE PATTERN_FLEXIBLE,
	  d.AGGREGATE_COLUMNS,
	  d.AGGREGATE_FUNCTIONS,
	  d.SUPPORT_SP_VERSIONS,
	  s.SOURCE_LABEL,
	  s.SOURCE_DATA,
	  s.TRANSFORMATION
  FROM DATA_AGGREGATION_TARGETS d
  JOIN DATA_AGGREGATION_SOURCES s
  USING(TARGET_ID)
  WHERE d.TARGET_DATA = :1
	AND s.SOURCE_ENABLED != :2;`;

var sourceStmt = snowflake.createStatement({
	sqlText: sourceQuery,
	binds: [TARGET_DATA, NON_ENABLED]
});

var sources = sourceStmt.execute();

// loop each source
while (sources.next()) {
	var targetData = sources.getColumnValue(1);
	var batchControlColumn = sources.getColumnValue(2);
	var batchControlSize = sources.getColumnValue(3);
	var batchControlNext = sources.getColumnValue(4);
	var patternColumns = sources.getColumnValue(5);
	var groupByColumns = sources.getColumnValue(6).map(x => x.split(':')[1]);
	var dimensionColumns = sources.getColumnValue(6).map(x => x.split(':')[0]);
	var groupByPattern = sources.getColumnValue(7);
	var groupByCompitable = sources.getColumnValue(8);
	var patternFlexible = sources.getColumnValue(9);
	var aggregateColumns = sources.getColumnValue(10).map(x => x.split(':')[1]);
	var measureColumns = sources.getColumnValue(10).map(x => x.split(':')[0]);
	var aggregateFunctions = sources.getColumnValue(11);
	var supportSpVersions = sources.getColumnValue(12);
	var sourceLabel = sources.getColumnValue(13);
	var sourceData = sources.getColumnValue(14);
	var transformation = sources.getColumnValue(15);
	var sourceTitle = '',
		sqlExecuted = '',
		sqlStatus = '',
		sqlResult = '(SP call parameter script_only is presented true)';

	if (transformation) { transformation = '(' + transformation + ')' } else { transformation = sourceData }

	if (groupByCompitable) {
		var flagIndexLast = patternColumns.length - 1,
			patternSegment = groupByPattern;
		var selectList = groupByColumns[0] === "DATA_PATTERN" ? (patternFlexible ? 'BITOR(' + groupByColumns[0] + ',' + groupByPattern + ')' : groupByPattern) + ' ' : '',
			dimensionList = '',
			groupByList = '',
			columnSplitter = '';
		for (var i = 0; i <= flagIndexLast; i++) {
			var flagPower = 2 ** (flagIndexLast - i);
			if (patternSegment / flagPower < 1) {
				dimensionList = dimensionList + columnSplitter + dimensionColumns[groupByColumns.indexOf(patternColumns[i])];
				selectList = selectList + columnSplitter + patternColumns[i];
				groupByList = groupByList + columnSplitter + patternColumns[i];
				columnSplitter = ',';
			}
			patternSegment %= flagPower;
		}

		var targetAlias = 'T.', sourceAlias = 'S.';
		var loadQuery = `MERGE INTO ` + targetData + ` ` + targetAlias[0] + ` \n`
			+ `USING ( \n`
			+ `  SELECT ` + groupByList + `,`
			+ aggregateFunctions.map((x, i) => { return x.replace('?', aggregateColumns[i]) + ' ' + aggregateColumns[i] }) + ` \n`
			+ `  FROM ( \n`
			+ `    SELECT ` + selectList + `,` + aggregateColumns + ` \n`
			+ `    FROM ` + transformation + ` \n`
			+ `    WHERE ` + batchControlColumn + ` >= :1 AND ` + batchControlColumn + ` < ` + batchControlNext + ` \n`
			+ `    ) \n`
			+ `  GROUP BY ` + groupByList + `\n`
			+ `  ) ` + sourceAlias[0] + ` \n`
			+ `ON ` + dimensionList.split(',').map((x, i) => { return `COALESCE(TO_CHAR(` + targetAlias + x + `),'') = COALESCE(TO_CHAR(` + sourceAlias + groupByList.split(',')[i] + `),'')` }).join('\n AND ') + ` \n`
			+ `WHEN MATCHED THEN UPDATE SET ` + measureColumns.map((x, i) => { return x + ' = ' + sourceAlias[0] + `.` + aggregateColumns[i] }) + ` \n`
			+ `WHEN NOT MATCHED THEN INSERT(` + dimensionList + `,` + measureColumns + `) \n`
			+ `VALUES (` + groupByList.split(',').map(x => { return sourceAlias[0] + `.` + x }) + `,`
			+ aggregateColumns.map(x => { return sourceAlias[0] + `.` + x }) + `);`;

		sqlExecuted = loadQuery.replace(/:2/g, batchControlSize).replace(/:1/g, "'" + BATCH_TIMETAG + "'");

		if (!SCRIPT_ONLY) {
			try {
				var loadStmt = snowflake.createStatement({
					sqlText: loadQuery,
					binds: [BATCH_TIMETAG, batchControlSize]
				});
				loadStmt.execute();
				sqlStatus = 'PASS';
				sqlResult = '[INFO-1] Successfully loaded data into target table'
			}
			catch (err) {
				sqlStatus = 'FAIL';
				sqlResult = '[FAIL] Failure to load data into target table => ' + err
			}
			finally {
				if (LOG_DETAILS || sqlStatus.startsWith('FAIL')) {
					var logQuery = 'INSERT INTO DATA_AGGREGATION_LOGGING(EVENT_TARGET, EVENT_SOURCE, EVENT_STATUS, EVENT_STATE, EVENT_QUERY) VALUES(:1, :2, :3, :4, :5)';
					var logStmt = snowflake.createStatement({
						sqlText: logQuery,
						binds: [targetData, sourceData, sqlStatus, sqlResult, sqlExecuted]
					});
					logStmt.execute()
				}
			}
		}
	}
	else {
		sqlExecuted = '-- No data is loaded from this source as the data pattern is incompatible!';
	}

	sourceTitle = pageBreaker + '-'.repeat(65)
		+ `\n-- SOURCE_LABEL: ` + sourceLabel
		+ `\n-- SOURCE_DATA: ` + sourceData.replace('DATAMART.BUYSIDE_NETWORK.', '').replace('DATAMART.SELLSIDE_NETWORK.', '')
		+ `\n-- SOURCE STATE: ` + sqlResult
		+ `\n` + '-'.repeat(65) + `\n`;
	sqlScript = sqlScript + sourceTitle + sqlExecuted;
	pageBreaker = `\n\n`;
}

return sqlScript;
$$;
--
-- Aggregate stored procedues to loop all available source tables
-- DROP PROCEDURE DATA_AGGREGATOR(VARCHAR, BOOLEAN, BOOLEAN);
--
CREATE PROCEDURE DATA_AGGREGATOR (
	TARGET_DATA VARCHAR,
	SCRIPT_ONLY BOOLEAN,
	LOG_DETAILS BOOLEAN
	)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT STRICT
AS
$$
var NON_ENABLED = 0;

var batchControlColumn = '',
	batchControlSize = 0,
	batchControlType = '',
	batchLoopTag = '',
	batchLoopEnd = '',
	batchScheduleCurrent;
var loopScript = '',
	pageBreaker = '',
	loopSegmenter = '',
	callStatus = '',
	callResult = '(SP call parameter script_only is presented true)';

//
// Detect runable or not
//
var targetQuery = `SELECT BATCH_CONTROL_COLUMN,
  BATCH_CONTROL_SIZE,
  BATCH_SCHEDULE_TYPE,
  --DATEADD(MINUTE, BATCH_CONTROL_SIZE, BATCH_PROCESSED) BATCH_LOOP_BEGIN,
  --DATEADD(MINUTE, -BATCH_CONTROL_SIZE, BATCH_POSSIBLE) BATCH_LOOP_END,
  DATEADD(MINUTE, CASE BATCH_SCHEDULE_TYPE
	  WHEN 'MINUTES' THEN BATCH_CONTROL_SIZE
	  WHEN 'HOURLY' THEN 60
	  ELSE 1440
	END, BATCH_PROCESSED) BATCH_LOOP_BEGIN,
  BATCH_POSSIBLE BATCH_LOOP_END,
  BATCH_SCHEDULE_CURRENT
FROM (
  SELECT BATCH_CONTROL_COLUMN,
	  BATCH_CONTROL_SIZE,
	  BATCH_CONTROL_NEXT,
	  BATCH_PROCESSED,
	  BATCH_PROCESSING,
	  BATCH_SCHEDULE_TYPE,
	  BATCH_SCHEDULE_LAST,
	  CURRENT_TIMESTAMP() BATCH_SCHEDULE_CURRENT,
	  CASE BATCH_SCHEDULE_TYPE
		WHEN 'HOURLY' THEN DATE_TRUNC(HOUR, BATCH_SCHEDULE_CURRENT)
		WHEN 'DAILY' THEN DATE_TRUNC(DAY, BATCH_SCHEDULE_CURRENT)
		ELSE DATEADD(MINUTE,FLOOR(DATEDIFF(MINUTE,'1970-01-01',BATCH_SCHEDULE_CURRENT)/BATCH_CONTROL_SIZE)*BATCH_CONTROL_SIZE,'1970-01-01')
	  END BATCH_POSSIBLE
  FROM (
	SELECT BATCH_CONTROL_COLUMN,
		BATCH_CONTROL_SIZE,
		BATCH_CONTROL_NEXT,
		BATCH_PROCESSED,
		BATCH_PROCESSING,
		BATCH_SCHEDULE_TYPE,
		BATCH_SCHEDULE_LAST,
		CURRENT_TIMESTAMP() BATCH_SCHEDULE_CURRENT
	FROM DATA_AGGREGATION_TARGETS
	WHERE TARGET_DATA = :1
	)
  )
WHERE BATCH_PROCESSING IS NULL
OR DATEDIFF(MINUTE, BATCH_SCHEDULE_LAST, BATCH_POSSIBLE) > BATCH_CONTROL_SIZE;`;

var targetStmt = snowflake.createStatement({
	sqlText: targetQuery,
	binds: [TARGET_DATA]
});

var target = targetStmt.execute();

if (target.next()) {
	batchControlColumn = target.getColumnValue(1);
	batchControlSize = target.getColumnValue(2);
	batchScheduleType = target.getColumnValue(3);
	batchLoopTag = target.getColumnValue(4);
	batchLoopEnd = target.getColumnValue(5);
	batchScheduleCurrent = target.getColumnValue(6);
}
else {
	return '\n\n-- Skip this schedule as previous schedule has not done yet!\n'
}

//
// Initialize the batch exclusion control context
//
var contextQuery = `UPDATE DATA_AGGREGATION_TARGETS \n `
	+ `SET BATCH_PROCESSING = :2, \n\t `
	+ `BATCH_SCHEDULE_LAST = :3 \n`
	+ `WHERE TARGET_DATA = :1;`;
var contextStmt = snowflake.createStatement({
	sqlText: contextQuery,
	binds: [TARGET_DATA, batchLoopEnd, batchScheduleCurrent]
});

if (!SCRIPT_ONLY) { contextStmt.execute(); }

//
// Loop and call the date_poplate SP for each batch
//
while (batchLoopTag <= batchLoopEnd) {
	var contextQuery = `UPDATE DATA_AGGREGATION_TARGETS \n `
		+ `SET BATCH_MICROCHUNK_CURRENT = :2 \n `
		+ `WHERE TARGET_DATA = :1;`;
	var contextStmt = snowflake.createStatement({
		sqlText: contextQuery,
		binds: [TARGET_DATA, batchLoopTag.toISOString()]
	});
	if (!SCRIPT_ONLY) { contextStmt.execute(); }

	var deleteQuery = `DELETE FROM ` + TARGET_DATA
		+ ` WHERE ` + batchControlColumn + ` >= :1`
		+ ` AND ` + batchControlColumn + ` < DATEADD(MINUTE, :2, :1);\n`;
	var deleteScheduled = deleteQuery
		.replace(/:2/g, batchControlSize.toString())
		.replace(/:1/g, '\'' + batchLoopTag.toISOString() + '\'');

	var callQuery = `CALL DATA_AGGREGATOR (:1, :2, :3, :4, :5);\n`;
	var callScheduled = callQuery
		.replace(/:1/g, '\'' + TARGET_DATA + '\'')
		.replace(/:2/g, SCRIPT_ONLY.toString())
		.replace(/:3/g, LOG_DETAILS.toString())
		.replace(/:4/g, NON_ENABLED.toString())
		.replace(/:5/g, '\'' + batchLoopTag.toISOString() + '\'');

	if (!SCRIPT_ONLY) {
		try {
			var removalStmt = snowflake.createStatement({
				sqlText: deleteQuery,
				binds: [batchLoopTag.toISOString(), batchControlSize]
			});
			removalStmt.execute();
			callStatus = 'PASS';
			callResult = '[INFO-1] Successfully deleted the existing data for reloading';
		}
		catch (err) {
			callStatus = 'FAIL';
			callResult = '[FAIL] Failure to delete the existing data from target table => ' + err
		}
		finally {
			if (LOG_DETAILS || callStatus.startsWith('FAIL')) {
				var logQuery = 'INSERT INTO DATA_AGGREGATION_LOGGING(EVENT_TARGET, EVENT_SOURCE, EVENT_STATUS, EVENT_STATE, EVENT_QUERY) VALUES(:1, :2, :3, :4, :5)';
				var logStmt = snowflake.createStatement({
					sqlText: logQuery,
					binds: [TARGET_DATA, '(*** All loaded data covered by current batch ***)', callStatus, callResult, deleteScheduled]
				});
				logStmt.execute()
			}
		}

		if (LOG_DETAILS) {
			var logQuery = 'INSERT INTO DATA_AGGREGATION_LOGGING(EVENT_TARGET, EVENT_SOURCE, EVENT_STATUS, EVENT_STATE, EVENT_QUERY) VALUES(:1, :2, :3, :4, :5)';
			var logStmt = snowflake.createStatement({
				sqlText: logQuery,
				binds: [TARGET_DATA, '(*** All enabled data sources ***)', 'INFO', '[INFO-2] Make a batch data load call', callScheduled]
			});
			logStmt.execute()
		}

		try {
			var callStmt = snowflake.createStatement({
				sqlText: callQuery,
				binds: [TARGET_DATA, SCRIPT_ONLY.toString(), LOG_DETAILS.toString(), NON_ENABLED.toString(), batchLoopTag.toISOString()]
			});
			callStmt.execute();
			callStatus = 'PASS';
			callResult = '[INFO-2] Successfully completed the batch load call';
		}
		catch (err) {
			callStatus = 'FAIL';
			callResult = '[FAIL] Failure to complete the batch load call => ' + err
		}
		finally {
			if (LOG_DETAILS || callStatus.startsWith('FAIL')) {
				var logQuery = 'INSERT INTO DATA_AGGREGATION_LOGGING(EVENT_TARGET, EVENT_SOURCE, EVENT_STATUS, EVENT_STATE, EVENT_QUERY) VALUES(:1, :2, :3, :4, :5)';
				var logStmt = snowflake.createStatement({
					sqlText: logQuery,
					binds: [TARGET_DATA, '', callStatus, callResult, callScheduled]
				});
				logStmt.execute()
			}
		}
	}

	loopSegmenter = pageBreaker + '-'.repeat(65)
		+ `\n-- LOOP FRAME: ` + batchControlColumn + ` = ` + batchLoopTag.toISOString()
		+ `\n-- LOOP CHUNK: ` + batchControlSize.toString() + ` minutes by ` + batchControlColumn
		+ `\n` + '-'.repeat(65) + `\n`;
	loopScript = loopScript + loopSegmenter + deleteScheduled + callScheduled;
	pageBreaker = `\n\n`;

	batchLoopTag.setMinutes(batchLoopTag.getMinutes() + batchControlSize);
}

//
// Clear the batch exclusion control context
//
var contextQuery = `UPDATE DATA_AGGREGATION_TARGETS T \n`
	+ `SET BATCH_MICROCHUNK_CURRENT = NULL, BATCH_PROCESSING = NULL, BATCH_PROCESSED = S.SOURCE_READY_TIME \n`
	+ `FROM ( \n`
	+ `SELECT d.TARGET_DATA, MIN(COALESCE(s.SOURCE_READY_TIME, d.BATCH_PROCESSED)) SOURCE_READY_TIME \n`
	+ `FROM DATA_AGGREGATION_TARGETS d \n`
	+ `JOIN DATA_AGGREGATION_SOURCES s \n`
	+ `USING(TARGET_ID) \n`
	+ `WHERE s.SOURCE_ENABLED = True \n`
	+ `GROUP BY d.TARGET_DATA \n`
	+ `) S \n`
	+ `WHERE T.TARGET_DATA = S.TARGET_DATA AND T.TARGET_DATA = :1;`;
var contextStmt = snowflake.createStatement({
	sqlText: contextQuery,
	binds: [TARGET_DATA]
});

if (!SCRIPT_ONLY) { contextStmt.execute(); }

return loopScript;
$$;
