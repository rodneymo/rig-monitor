#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# epoch TIME
TIME=`date +%s%N`

# load and capture claymore's http status page 
CLAYMORE_READOUT=`timeout 5s w3m -dump -cols 1000 http://${RIG_IP}:3333 | awk -vRS= 'END{print}'`
if (( DEBUG == 1 )); then
	echo "$TIME $CLAYMORE_READOUT"
fi

# check if no response from w3m
if [ "$CLAYMORE_READOUT" == "" ]; then
        echo "w3m FAILED"
        DATA_BINARY="miner_system,rig_id=${RIG_ID},miner=claymore,coin=${COIN_LABEL},dcoin=${DCOIN_LABEL} installed_gpus=${INSTALLED_GPUS},active_gpus=-1,target_hr=${TARGET_HR},total_hr=-1,total_hr_dcoin=-1,target_hr_dcoin=${TARGET_HR_DCOIN}"
        #curl -s -i -m 5 -XPOST 'http://localhost:8086/write?db=rigdata' --data-binary "${DATA_BINARY}"
else
	# parse miner output, prepare data for influxdb ingest and filter out null tags, fields

	DATA_POINTS=`awk -f ${BASE_DIR}/awk/parse_claymore_status.awk \
		-v time=${TIME} rig_id=${RIG_ID} coin=${COIN_LABEL} dcoin=${DCOIN_LABEL} installed_gpus=${INSTALLED_GPUS} \
		target_hr_eth=${TARGET_HR} target_hr_dcoin=${TARGET_HR_DCOIN} \
		<<< "$CLAYMORE_READOUT" `
	LINE=`echo "${DATA_POINTS}" |  sed -e 's/[a-z0-9_]\+=,//g' -e 's/,[a-z0-9_]\+= $//g'`
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
fi

if (( DEBUG == 1 )); then
        echo "$LINE"
fi

IFS=$SAVEIFS

