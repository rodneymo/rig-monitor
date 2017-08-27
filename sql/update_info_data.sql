truncate table info_rig;
truncate table info_gpu;

LOAD DATA LOCAL INFILE './tmp/rig_info.tmp'
INTO TABLE rigdata.info_rig
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(rig_name,ip_address, plug_ip, installed_gpus, target_hashrate, target_temp, max_power) SET rig_id = NULL;

LOAD DATA LOCAL INFILE './tmp/gpu_info.tmp'
INTO TABLE rigdata.info_gpu
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(rig_gpu_id, model, memory, processors);

