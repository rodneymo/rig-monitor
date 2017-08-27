LOAD DATA LOCAL INFILE './tmp/rig_status.tmp'
INTO TABLE rigdata.status_rig
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(@var1, rig_name, working_gpus, average_hashrate, total_shares, total_rej_shares, power_usage, mining_time) SET time = FROM_UNIXTIME(@var1);

LOAD DATA LOCAL INFILE './tmp/gpu_status.tmp'
INTO TABLE rigdata.status_gpu
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(@var1, rig_gpu_id, gpu_hashrate, gpu_shares, gpu_inc_shares, gpu_temp, gpu_fan) SET time = FROM_UNIXTIME(@var1);

