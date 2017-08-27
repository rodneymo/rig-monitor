drop table IF EXISTS rigdata.info_gpu;
drop table IF EXISTS rigdata.info_rig;
drop table IF EXISTS rigdata.status_rig;
drop table IF EXISTS rigdata.status_gpu;

CREATE DATABASE IF NOT EXISTS rigdata;

CREATE USER IF NOT EXISTS 'grafana'@localhost IDENTIFIED BY 'grafana';
GRANT SELECT ON `rigdata`.* TO `grafana`@`localhost` ;

CONNECT rigdata;

CREATE TABLE info_rig(
	rig_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
	rig_name VARCHAR(10) NOT NULL,
	ip_address VARCHAR(20) NOT NULL,
	plug_ip  VARCHAR(20) NOT NULL,
	installed_gpus INT NOT NULL,
	target_hashrate FLOAT(7,3) NOT NULL,
	target_temp INT NOT NULL,
	max_power INT NOT NULL
   );

CREATE TABLE info_gpu(
	rig_gpu_id VARCHAR(12) NOT NULL,
	model VARCHAR(20) NOT NULL,
	memory  INT NOT NULL,
	processors INT NOT NULL
   );
   
CREATE TABLE status_rig(
	time DATETIME,
	rig_name VARCHAR(10) NOT NULL,
	working_gpus INT NOT NULL,
	average_hashrate FLOAT(7,3),
	total_shares INT,
	total_rej_shares INT,
	power_usage INT,
	mining_time TIME,
	PRIMARY KEY(time,rig_name)
   );
   
CREATE TABLE status_gpu(
	time DATETIME,
	rig_gpu_id VARCHAR(12) NOT NULL,
	gpu_hashrate FLOAT(7,3) NOT NULL,
	gpu_shares INT NOT NULL,
	gpu_inc_shares INT,
	gpu_temp INT NOT NULL,
	gpu_fan INT NOT NULL,
	PRIMARY KEY(time,rig_gpu_id)
   );


