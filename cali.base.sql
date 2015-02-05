##################################
# cali.base			 #
# (c)2008-2011 - Claudio Nanni	 #
##################################

#> BASE API:

#> Function: collectors
#>	        	  WHEN  'add'
#>                WHEN  'remove'
#>                WHEN  'list'
#>                WHEN  'count'
#> Function: poll_collectors
#>                WHEN  'get'
#>                WHEN  'set'
#>                WHEN  'enable'
#>                WHEN  'disable'


# Make sure the database is brand new
drop database if exists caligula;
create database caligula;
grant all privileges on caligula.* to 'caligula'@'%' identified by 'changenow';

####################################################################################################
# MAIN REPOSITORY
####################################################################################################
### MEASURED SYSTEM WILL BE NAMED SYSTEM_ID. A Good value could be "network_id.host_id"
####################################################################################################
# DATA VAULT
DROP TABLE IF EXISTS `caligula`.`collectors_data`;
CREATE TABLE `caligula`.`collectors_data` (
  `system_id` varchar(64) DEFAULT 'unique id of the source',
  `variable_class` varchar(128) NOT NULL DEFAULT '', # this aggregates: service instance+var class, for now
  `variable_name` varchar(128) NOT NULL DEFAULT '',
  `variable_value` varchar(128) NOT NULL DEFAULT '',
  `sample_timestamp` timestamp NOT NULL DEFAULT '0000-00-00',
  `collect_timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `coll_id` int(11) unsigned NOT NULL,
  PRIMARY KEY (`system_id`,`variable_class`,`variable_name`,`collect_timestamp`),
  KEY `collect_timestamp` (`collect_timestamp`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;


####################################################################################################
# Main Configuration Table
####################################################################################################

#MAIN/ONLY CONFIGURATION TABLE
CREATE TABLE caligula.collectors (
  `coll_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `coll_name` varchar(64) NOT NULL default 'collector_00x',
  `coll_ipaddress` varchar(15) NOT NULL default '',
  `coll_mysqlport` varchar(5) default '3306',
  `coll_username` varchar(16) NOT NULL default 'caligula',
  `coll_password` varchar(16) NOT NULL default 'changenow',
  `coll_dbname` varchar(64) NOT NULL default 'caligula',
  PRIMARY KEY (`coll_id`),
  UNIQUE (`coll_name`),
  UNIQUE (`coll_ipaddress`,`coll_mysqlport`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


####################################################################################################
# Main Polling Scheduler controlled by the API poll_collectors()
####################################################################################################

# Here we create the EVENT that will poll data from collectors (collectors)
use caligula;
drop event if exists caligula._PRIVATE_pull_collectors_data;
delimiter |
CREATE EVENT caligula._PRIVATE_pull_collectors_data
    ON SCHEDULE
      EVERY 2 MINUTE
    COMMENT 'Poll remote collector_data on master vault'
    DO
      BEGIN
	call _PRIVATE_poll_collectors();
      END |
delimiter ;
set global event_scheduler=ON;

####################################################################################################

DROP PROCEDURE IF EXISTS _PRIVATE_poll_collectors;
	DELIMITER |
	CREATE PROCEDURE _PRIVATE_poll_collectors()
	BEGIN
	  DECLARE done INT DEFAULT 0;
	  DECLARE id_coll INT DEFAULT -9;
	  DECLARE system_id,username,password,ipaddress,port,dbname,tablename VARCHAR(32);
	  DECLARE connection_string VARCHAR(256);
	  DECLARE max_ts DATETIME;
	  DECLARE cur1 CURSOR FOR SELECT coll_id,system_id,coll_username,coll_password,coll_ipaddress,coll_mysqlport,coll_dbname from caligula.collectors;
	  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
	  OPEN cur1;
	  read_loop: LOOP
	    FETCH cur1 INTO id_coll,system_id,username,password,ipaddress,port,dbname;
	    IF done THEN
	      LEAVE read_loop;
	    END IF;
		set @tablename := 'collector_data';
		set @connection_string := concat('mysql://',username,':',password,'@',ipaddress,':',port,'/',dbname,'/',@tablename);
		### THIS IS ACTUALLY A DYNAMICALLY CREATED CONNECTION (ORACLE DBLink) - Prepared statement's the only option for dynamic SQL
		set @stmt1_def = concat(	
		'CREATE TABLE caligula._PRIVATE_gateway(
		  `variable_class` varchar(128) not null,
		  `variable_name` varchar(128) not null,
		  `variable_value` varchar(128) not null,
		  `system_id` varchar(64) not NULL,
        `sample_timestamp` timestamp ,
   	  `collect_timestamp` timestamp ,
		  KEY `variable_cn` (`variable_class`,`variable_name`),
		  KEY `collect_timestamp` (`collect_timestamp`)
		) ENGINE=FEDERATED
		CONNECTION=\'',@connection_string,'\'');
		DROP TABLE IF EXISTS caligula._PRIVATE_gateway;
		PREPARE stmt1 FROM @stmt1_def;
		EXECUTE stmt1;
		DEALLOCATE PREPARE stmt1;
		### Get the collector system_id from the remote table to match it to the local table and get the last update time on this central console
      ### I have added the COLLECTOR unique id in the Collectors table and I will add this info to the BASE table records every time I pull from the Collectors (they dont know their ID!)
		set @max_ts := (select ifnull((select collect_timestamp from caligula.collectors_data where coll_id=id_coll order by collect_timestamp desc limit 1),'2000-01-01 00:00:00')); ## This in case its the first time we pull data from this Collector
		insert ignore into caligula.collectors_data select *,id_coll from caligula._PRIVATE_gateway where collect_timestamp>@max_ts;
	END LOOP;
	  CLOSE cur1;
	  ## Since it contains connection info we drop it for safety; we could user the SERVER construct but introduces a bit of overhead
          DROP TABLE IF EXISTS caligula._PRIVATE_gateway;
	END |
DELIMITER ;
####################################################################################################



####################################################################################################
#  Service Function to split parameters of API
####################################################################################################

     CREATE FUNCTION _PRIVATE_SPLIT_STR(
	  x VARCHAR(4096),
	  delim VARCHAR(12),
	  pos INT
	)
	RETURNS VARCHAR(4096)
   DETERMINISTIC
	RETURN REPLACE(SUBSTRING(SUBSTRING_INDEX(x, delim, pos),
	       LENGTH(SUBSTRING_INDEX(x, delim, pos -1)) + 1),
	       delim, '');


####################################################################################################
# API to control configuration: Add, Delete, List, Count the Collectors
####################################################################################################
		DROP PROCEDURE IF EXISTS caligula.collectors;
		DELIMITER |
		CREATE PROCEDURE caligula.collectors(pAllParams varchar(255))
		#> Pass 5 parameters in one single string separated by a pipe |
		#> Param 1 - Function that you want to call: 'list' 'add' 'remove'  	DEFAULT 'add'		NOTE: 'list' returns the collectors
		#> Param 2 - Ip Address of the MySQL where the collector is running: 	DEFAULT 127.0.0.1  	NOTE: default is added an collector on this same host as the 'base'
		#> Param 3 - Port of the MySQL where the collector is running: 		DEFAULT 3306		NOTE: there can be more than one collector on the same host
		#> Param 4 - Username to connect to the collector:				DEFAULT caligula	NOTE: its created the same on collectors as default
		#> Param 5 - Password to connect to the collector:				DEAFULT changenow	NOTE: its created the same on collectors as default
		
		#> since the most common operation will be add an collector a call like this: call caligula.collectors('|192.168.1.123');
		#> will create add an collector on host 192.168.1.123 that listens on port 3306 and uses default l/p
		#> For simplicity we dont introduce a function to just update user and/or password. Just remove an collector and reinsert it.

		BEGIN
		SELECT
			lcase(_PRIVATE_SPLIT_STR(pAllParams,'|',1)),
			_PRIVATE_SPLIT_STR(pAllParams,'|',2),
			_PRIVATE_SPLIT_STR(pAllParams,'|',3),
			_PRIVATE_SPLIT_STR(pAllParams,'|',4),
			_PRIVATE_SPLIT_STR(pAllParams,'|',5)
		INTO
			@pFunc,
			@pIpAd,
			@pPort,
			@pUser,
			@pPass;

		#> Here I define the default values
		IF @pFunc='' THEN SET @pFunc := 'list'; END IF;
		IF @pIpAd='' THEN SET @pIpAd := '127.0.0.1'; END IF;
		IF @pPort='' THEN SET @pPort := '3306'; END IF;
		IF @pUser='' THEN SET @pUser := 'caligula'; END IF;
		IF @pPass='' THEN SET @pPass := 'changenow'; END IF;

		CASE @pFunc
    		WHEN 'add'
		THEN
			SELECT CONCAT('Adding collector on [',@pIpAD,'.',@pPort ,']') as info;
			INSERT INTO caligula.collectors (coll_ipaddress,coll_mysqlport,coll_username,coll_password)
				VALUES (@pIpAd,@pPort,@pUser,@pPass);
			#call caligula.install_collector();
    		WHEN 'remove'
		THEN
			SELECT CONCAT('Deleting Collector ',@pIpAd) as info;
			delete from caligula.collectors where coll_id=@pIpAd;
    		WHEN 'list'
		THEN    ### In case you choose LIST the default (127.0.0.1) means to me, LIST ALL
			if @pIpAd='127.0.0.1' THEN SET @pIpAd := '%';  SET @pPort := '%'; END IF;
			SELECT * FROM caligula.collectors where coll_ipaddress LIKE @pIpAd and coll_mysqlport LIKE @pPort;
		WHEN 'count'
		THEN
			SELECT count(*) as `Number of collectors` FROM caligula.collectors;
		ELSE SELECT CONCAT('I am sorry, but the function [',@pFunc,'] is not supported.') as error;
		END CASE;


		END |
	DELIMITER ;


	DELIMITER |
	CREATE PROCEDURE caligula.poll_collectors(pAllParams varchar(255))
	BEGIN
		SELECT
			lcase(_PRIVATE_SPLIT_STR(pAllParams,'|',1)),
			_PRIVATE_SPLIT_STR(pAllParams,'|',2)
		INTO
			@pFunc,
			@pIntr;

		#> Here I define the default values
		IF @pFunc='' THEN SET @pFunc := 'get'; END IF;
		IF @pIntr='' THEN SET @pIntr := '3'; END IF;

		CASE @pFunc
    		WHEN 'get'
		THEN
			SELECT CONCAT(INTERVAL_VALUE,' ',INTERVAL_FIELD,'(S) ',STATUS) as poll_interval
			FROM information_schema.events
			WHERE EVENT_SCHEMA='caligula' AND EVENT_NAME='_PRIVATE_pull_collectors_data';
		WHEN 'set'
		THEN
			ALTER EVENT caligula._PRIVATE_pull_collectors_data
			ON SCHEDULE
			EVERY @pIntr MINUTE;
			SELECT CONCAT(INTERVAL_VALUE,' ',INTERVAL_FIELD,'(S)') as new_poll_interval
			FROM information_schema.events
			WHERE EVENT_SCHEMA='caligula' AND EVENT_NAME='_PRIVATE_pull_collectors_data';
      WHEN 'enable'
		THEN
			ALTER EVENT caligula._PRIVATE_pull_collectors_data ENABLE;
			SELECT STATUS as `ENABLE POLLING`
			FROM information_schema.events
			WHERE EVENT_SCHEMA='caligula' AND EVENT_NAME='_PRIVATE_pull_collectors_data';

      WHEN 'disable'
		THEN
			ALTER EVENT caligula._PRIVATE_pull_collectors_data DISABLE;
			SELECT STATUS  as `DISABLE POLLING`
			FROM information_schema.events
			WHERE EVENT_SCHEMA='caligula' AND EVENT_NAME='_PRIVATE_pull_collectors_data';
      WHEN 'last'
      THEN
            select
              LAST_EXECUTED 'Last Polling',
              now() 'Current Time',
              date_add(LAST_EXECUTED,INTERVAL INTERVAL_VALUE MINUTE) 'Next Polling'
              from information_schema.EVENTS
            where EVENT_NAME='_PRIVATE_pull_collectors_data';
		ELSE
			SELECT CONCAT('I am sorry, but the function [',@pFunc,'] is not supported.') as error;
		END CASE;
	END |
	DELIMITER ;




####################################################################################################
# API : Shows functions and parameters: Its all automatic but based on the following:
#       When you define a stored procedure the parameter check (the first one=function) must
#       be defined as follows:   WHEN<SP>'<function>'     if you define the check like that
#       your function name will be showed by this procedure.
####################################################################################################
		DROP PROCEDURE IF EXISTS caligula.api;
		DELIMITER |
		CREATE PROCEDURE caligula.api()
      BEGIN
      drop table if exists _PRIVATE_counter2to10;
      create table _PRIVATE_counter2to10 (id int);
      insert into _PRIVATE_counter2to10 VALUES (2),(3),(4),(5),(6),(7),(8),(9),(10);
      
      select
concat(	ROUTINE_NAME,
	'.',
	caligula._PRIVATE_SPLIT_STR(
        caligula._PRIVATE_SPLIT_STR(
            ROUTINE_DEFINITION,
            'WHEN \'',
            c.id),
        '\'',
        1)) as 'Object Oriented Notation',
        concat(	'call ',ROUTINE_NAME,'(\'',
	caligula._PRIVATE_SPLIT_STR(
        caligula._PRIVATE_SPLIT_STR(
            ROUTINE_DEFINITION,
            'WHEN \'',
            c.id),
        '\'',
        1),'\')') as 'SQL Syntax'
        
        
  from
       information_schema.ROUTINES, _PRIVATE_counter2to10 c
  where
       ROUTINE_SCHEMA='caligula'
  and
       ROUTINE_NAME not like '%_PRIVATE_%'
  and
       concat( ROUTINE_NAME,
               '.',
               caligula._PRIVATE_SPLIT_STR(
                    caligula._PRIVATE_SPLIT_STR(
                         ROUTINE_DEFINITION,
                         'WHEN \'',
                         c.id),
                    '\'',
                    1)) not like '%.'
ORDER BY 1;

    
    
 		END |
	DELIMITER ;

