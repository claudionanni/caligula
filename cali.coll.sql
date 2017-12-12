##########################################################
# Caligula: cali.collector	(c)2008-2011 - Claudio Nanni	 #
##########################################################

# Make sure the database is there
create database if not exists caligula;
grant all privileges on caligula.* to 'caligula'@'%' identified by 'changenow';


####################################################################################################
# Collector CORE: The collector Table where different data providers can put their data
####################################################################################################
####################################################################################################
### MEASURED SYSTEM renamed SYSTEM_ID. Good value could be "network_id.host_id.service_type.service_id"
####################################################################################################
# This is actually the only fundamental thing that a Collector has to have
# The table where we collect data from any data provider(system_id)
# Default: we have 1 system_id that is this collector itself which will pull 2 classes of variables: (global_status,global_variables)
        CREATE DATABASE IF NOT EXISTS caligula;
	DROP TABLE IF EXISTS `caligula`.`collector_data`;
	CREATE TABLE `caligula`.`collector_data` (
	  `system_id` varchar(64) DEFAULT 'hostname',
    `variable_class` varchar(128) NOT NULL DEFAULT 'mysql.3306.information_schema.global_status', # may be move -mysql.3306- to service_instance, or service_id (to add)
  	`variable_name` varchar(128) NOT NULL DEFAULT 'com_select',
  	`variable_value` varchar(4096) NOT NULL DEFAULT '0',
  	`sample_timestamp` timestamp NOT NULL DEFAULT '0000-00-00',
    `collect_timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
     KEY `variable_cn` (`variable_class`,`variable_name`),
	  KEY `time_stamp` (`collect_timestamp`)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;
####################################################################################################

#  If you wonder about 'system_id'. It's a unique identifier in our domain(mathematical), it can be usually the hostname/hostid, or any unique naming convention.
#  In case the service has a port number you use it, otherwise invent it. This allows also collecting data of multiple mysql installations on same host.
#  Very important to identify: [1]system [2]service [3]variable (system_id,variable_class,variable_name)


