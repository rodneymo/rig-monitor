#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# epoch TIME
TIME=`date +%s%N`

exec 3<>/dev/tcp/$RIG_IP/3333
echo "{\"command\": \"summary+devs\"}" >&3

# load and capture sgminer's http status page 
SGMINER_READOUT=`cat <&3 | jq -r '.'`
if (( DEBUG == 1 )); then
	echo "$SGMINER_READOUT"
fi

FIELDS=`echo $SGMINER_READOUT | jq -r '.summary[0].SUMMARY[0] | "hr_avg=\(."MHS av") total_shares=\(.Accepted) rej_shares=\(.Rejected) stale_shares=\(.Stale) hw_errors=\(."Hardware Errors")"'`
_MINING_TIME=`echo $SGMINER_READOUT | jq -r '.summary[0].SUMMARY[0].Elapsed'` 
MINING_TIME=$(convertsecs $_MINING_TIME)
NUM_GPUS=`echo $SGMINER_READOUT | jq -r '.devs[0].STATUS[0].Msg' | sed -e 's/ .*$//'`

LINE="miner_system_sgminer,rig_id=${RIG_ID},miner=sgminer,coin=${COIN_LABEL},installed_gpus=${INSTALLED_GPUS},active_gpus=${NUM_GPUS},target_hr=${TARGET_HR},mining_time='"${MINING_TIME}"'"
echo "$LINE"

#print "miner_system_claymore,rig_id=" rig_id ",miner=claymore,coin=" coin ",dcoin=" dcoin " " "installed_gpus=" installed_gpus ",active_gpus=" NUM_GPUS ",targe
#t_hr="target_hr ",total_hr=" total_hr",avg_hr_1m=" avg_hr_1m ",total_shares=" total_shares ",rej_shares=" rej_shares ",target_hr_dcoin=" target_hr_dcoin ",total_hr_dco
#in=" total_hr_dcoin ",avg_hr_1m_dcoin=" avg_hr_1m_dcoin ",total_shares_dcoin=" total_shares_dcoin ",rej_shares_dcoin=" rej_shares_dcoin ",mining_time=\"" mining_time "
#\""

#print "miner_gpu_claymore,rig_id=" rig_id ",gpu_id=" gpu_id ",gpu_specs=" gpu[gpu_id,"SPECS"] " " "gpu_hr=" gpu[gpu_id,"HR"] ",gpu_shares=" gpu[gpu_id,
#"SHARES"] ",gpu_inc_shares=" gpu[gpu_id,"INC_SHARES"] ",gpu_hr_dcoin=" gpu[gpu_id,"HR_DCOIN"] ",gpu_shares_dcoin=" gpu[gpu_id,"SHARES_DCOIN"] ",gpu_inc_shares_dcoin=" 
# gpu[gpu_id,"INC_SHARES_DCOIN"] ",gpu_max_temp=" gpu_max_temp ",gpu_temp=" gpu[gpu_id,"TEMP"] ",gpu_fan=" gpu[gpu_id,"FAN"]


# parse miner output, prepare data for influxdb ingest and filter out null tags, fields

if (( DEBUG == 1 )); then
        echo "$DATA_BINARY"
fi


