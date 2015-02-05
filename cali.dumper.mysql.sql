#######
### WATCH OUT: When you modify the collectors_data table to bring the 'measured_system' to global O.O. notation remember to change the query here to reflect the change.
#######
### If needed enable the EVENT SCHEDULER(disabled by default) with: SET GLOBAL event_scheduler=1
#######
create database if not exists caligula;
use caligula;
grant all privileges on caligula.* to 'caligula'@'%' identified by 'changenow';
####################################################################################################
# Service Function
####################################################################################################
#Function used for the parameters in the Stored Procedures
	CREATE FUNCTION caligula._PRIVATE_SPLIT_STR(
	  x VARCHAR(255),
	  delim VARCHAR(12),
	  pos INT
	)
	RETURNS VARCHAR(255)
	DETERMINISTIC
	RETURN REPLACE(SUBSTRING(SUBSTRING_INDEX(x, delim, pos),
	       LENGTH(SUBSTRING_INDEX(x, delim, pos -1)) + 1),
	       delim, '');
####################################################################################################
####################################################################################################
# SCHEDULER: Used to collect internal MySQL Data like Status and Variables
####################################################################################################
	# Here we create the EVENT that will update the two tables every 60 seconds by default. Remember to enable it: SET GLOBAL event_scheduler=1;
	drop event if exists caligula._PRIVATE_update_collector_data;
	delimiter |
	CREATE EVENT caligula._PRIVATE_update_collector_data
	    ON SCHEDULE
	      EVERY 60 SECOND
	    COMMENT 'Update local data table that collects all scheduled data'
	    DO
	      BEGIN
              call caligula._PRIVATE_mysqldumper_dump_global_status;
              call caligula._PRIVATE_mysqldumper_dump_global_variables;
              call caligula._PRIVATE_mysqldumper_dump_processlist;
	      END |
	delimiter ;
####################################################################################################



####################################################################################################
# Dumper: mysql.localhost.3306, Class+Variable: mysql.information_schema.global_status
####################################################################################################

DELIMITER |
	CREATE PROCEDURE caligula._PRIVATE_mysqldumper_dump_global_status()
	BEGIN
	#        select VARIABLE_VALUE INTO @hostname from information_schema.global_variables where lcase(VARIABLE_NAME)='hostname';
	#        select VARIABLE_VALUE INTO @mysqlport from information_schema.global_variables where lcase(VARIABLE_NAME)='port';
	#        ### I Use 'mysql'.HOST.PORT as unique identifier. I would like to use IP.PORT but I cant get the IP for now.
  #    set @sys_id := @hostname;
	 #  set @var_class := concat('mysql','.',@mysqlport,'.information_schema.global_status');
	 #  ## if you wonder why not select now() in the insert: I want a unique time stamp for all this event execution
	 #  select now() into @sampling_and_collect_time;
	
    ## @sys_id/@hostname is the id of the system generating the variables values, roughly = 1 computer
    select VARIABLE_VALUE INTO @hostname from information_schema.global_variables where lcase(VARIABLE_NAME)='hostname';
    select VARIABLE_VALUE INTO @mysqlport from information_schema.global_variables where lcase(VARIABLE_NAME)='port';
    set @sys_id := concat(@hostname,'.',@mysqlport);
		
    ## @mysqlport I use to generate the service_id. There can be several mysql(or anything else) running on a system, port is ONE way to distinguish
	  set @var_class := 'mysql.information_schema.global_status';
		## Here is kind of merged for now the concept of:  service_id and variable class, we can use a OO notation.
    ## mysql.3306.global_status , or os.cpu, or os.disk, or as I did here also specifying where the info comes from (information_schema), not really correct.. :)
      
    ## if you wonder why not select now() in the insert: I want a unique time stamp for all this event execution
		select now() into @sampling_and_collect_time;
   
   
	### RETRIEVE #1: information_schema.global_status 
	      insert into caligula.collector_data
        select
				  @sys_id,
				  @var_class,
				  VARIABLE_NAME,
				  VARIABLE_VALUE,
				  @sampling_and_collect_time,
          @sampling_and_collect_time
			  from 
				  information_schema.global_status;
      END |
DELIMITER ;
####################################################################################################

####################################################################################################
# DATA PROVIDER: mysql.information_schema.global_variables
####################################################################################################

DELIMITER |
	CREATE PROCEDURE caligula._PRIVATE_mysqldumper_dump_global_variables()
	BEGIN
	  ## @sys_id/@hostname is the id of the system generating the variables values, roughly = 1 computer
    select VARIABLE_VALUE INTO @hostname from information_schema.global_variables where lcase(VARIABLE_NAME)='hostname';
    select VARIABLE_VALUE INTO @mysqlport from information_schema.global_variables where lcase(VARIABLE_NAME)='port';
    set @sys_id := concat(@hostname,'.',@mysqlport);
		
    ## @mysqlport I use to generate the service_id. There can be several mysql(or anything else) running on a system, port is ONE way to distinguish
	  set @var_class := 'mysql.information_schema.global_variables';
		## Here is kind of merged for now the concept of:  service_id and variable class, we can use a OO notation.
    ## mysql.3306.global_variables , or os.cpu, or os.disk, or as I did here also specifying where the info comes from (information_schema), not really correct.. :)
      
    ## if you wonder why not select now() in the insert: I want a unique time stamp for all this event execution
		select now() into @sampling_and_collect_time;

### RETRIEVE #2: information_schema.global_variables 
	      insert into caligula.collector_data
        select
          @sys_id,
          @var_class,
			    VARIABLE_NAME,
			    VARIABLE_VALUE,
 			   @sampling_and_collect_time,
          @sampling_and_collect_time
        from 
			    information_schema.global_variables;
      END |
DELIMITER ;
####################################################################################################


####################################################################################################
# DATA PROVIDER: mysql.information_schema.processlist
####################################################################################################

DELIMITER |
        CREATE PROCEDURE caligula._PRIVATE_mysqldumper_dump_processlist()
        BEGIN
          ## @sys_id/@hostname is the id of the system generating the variables values, roughly = 1 computer
    select VARIABLE_VALUE INTO @hostname from information_schema.global_variables where lcase(VARIABLE_NAME)='hostname';
    select VARIABLE_VALUE INTO @mysqlport from information_schema.global_variables where lcase(VARIABLE_NAME)='port';
    set @sys_id := concat(@hostname,'.',@mysqlport);
                
    ## @mysqlport I use to generate the service_id. There can be several mysql(or anything else) running on a system, port is ONE way to distinguish
          set @var_class := 'mysql.information_schema.processlist';
                ## Here is kind of merged for now the concept of:  service_id and variable class, we can use a OO notation.
    ##!RV! mysql.3306.processlist , or os.cpu, or os.disk, or as I did here also specifying where the info comes from (information_schema), not really correct.. :)
      
    ## if you wonder why not select now() in the insert: I want a unique time stamp for all this event execution
                select now() into @sampling_and_collect_time;

### RETRIEVE #2: information_schema.processlist 
              insert into caligula.collector_data
        select
          @sys_id,
          @var_class,
                            ID PROCESS_ID,
                            concat_ws(',','"',ID,USER,HOST,DB,COMMAND,TIME,STATE,INFO,TIME,STAGE,MAX_STAGE,PROGRESS,'"') PROCESS,
                           @sampling_and_collect_time,
          @sampling_and_collect_time
        from 
                            information_schema.processlist;
      END |
DELIMITER ;
####################################################################################################




####################################################################################################
# API: SCHEDULER CONTROL
####################################################################################################

## This is the API to control the scheduler on the agent
DELIMITER |
	CREATE PROCEDURE caligula.mysqldumper(pAllParams varchar(255))
	BEGIN
		SELECT 
			lcase(_PRIVATE_SPLIT_STR(pAllParams,'|',1)),
			_PRIVATE_SPLIT_STR(pAllParams,'|',2)
		INTO
			@pFunc,
			@pIntr;

		#> Here I define the default values
		IF @pFunc='' THEN SET @pFunc := 'get'; END IF;
		IF @pIntr='' THEN SET @pIntr := '1'; END IF;

		CASE @pFunc
      WHEN 'get' 
      THEN 
          SELECT CONCAT(INTERVAL_VALUE,' ',INTERVAL_FIELD,'(S) ',STATUS) as Update_Interval
          FROM information_schema.events
          WHERE EVENT_SCHEMA='caligula' AND EVENT_NAME='_PRIVATE_update_collector_data';
      WHEN 'set' 
      THEN 
          ALTER EVENT caligula._PRIVATE_update_collector_data
          ON SCHEDULE
          EVERY @pIntr SECOND;
          SELECT CONCAT(INTERVAL_VALUE,' ',INTERVAL_FIELD,'(S)') as New_Update_Interval
          FROM information_schema.events
          WHERE EVENT_SCHEMA='caligula' AND EVENT_NAME='_PRIVATE_update_collector_data';
      WHEN 'enable'
      THEN 
          ALTER EVENT caligula._PRIVATE_update_collector_data ENABLE;
          SELECT STATUS as `ENABLE DUMPER`
          FROM information_schema.events
          WHERE EVENT_SCHEMA='caligula' AND EVENT_NAME='_PRIVATE_update_collector_data';
      WHEN 'disable' 
      THEN 
          ALTER EVENT caligula._PRIVATE_update_collector_data DISABLE;
          SELECT STATUS  as `DISABLE DUMPER`
          FROM information_schema.events
          WHERE EVENT_SCHEMA='caligula' AND EVENT_NAME='_PRIVATE_update_collector_data';
      WHEN 'export'
      THEN
          SELECT * from caligula.collector_data INTO OUTFILE '/tmp/caligula.export';
      WHEN 'import'
      THEN
	  SELECT '<currently disabled function>' AS MESSAGE;
	  #CREATE TABLE IF NOT EXISTS caligula.collector_data_import like caligula.collector_data;
	  #load data local infile '/tmp/caligula.export' into table caligula.collector_data_import;
      ELSE SELECT CONCAT('I am sorry, but the function [',@pFunc,'] is not supported.') as error;
		END CASE;
	END |
	DELIMITER ;
####################################################################################################
  
