#Create collector table to collect data on this mysql instance (from various sources is theoretically possible, now only internal mysql)
source cali.coll.sql 
#Create the MySQL Dumper agent. It is an Event based agent that logs in the collector_data table some mysql stuff: status, variables, processlist
#It has also a sort of api reachable via the stored procedure:  mysqldumper(''); see code for the implemented functions.
#This api is used to enable and disable the event, to change the interval, and to export the collector_data into /tmp/caligula.export, LOADable then via LOAD INFILE
source cali.dumper.mysql.sql
#Enables the event scheduler in this instance.
SET GLOBAL event_scheduler=1;

