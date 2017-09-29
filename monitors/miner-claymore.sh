#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# epoch TIME
TIME=`date +%s%N`

# load and capture claymore's http status page 
CLAYMORE_READOUT=`timeout 5s w3m -dump -cols 1000 http://${RIG_IP}:3333 | awk -vRS= 'END{print}'`
if (( DEBUG == 1 )); then
	echo "$TIME $CLAYMORE_READOUT"
fi


# parse miner output, prepare data for influxdb ingest and filter out null tags, fields
DATA_POINTS=`awk -f ${BASE_DIR}/awk/parse_claymore_status.awk \
	-v time=${TIME} rig_id=${RIG_ID} coin=${COIN_LABEL} dcoin=${DCOIN_LABEL} installed_gpus=${INSTALLED_GPUS} \
	target_hr_eth=${TARGET_HR_ETH} target_hr_dcoin=${TARGET_HR_DCOIN} 
	<<< "$CLAYMORE_READOUT" `
DATA_BINARY=`echo "${DATA_POINTS}" |  sed -e 's/[a-z0-9_]\+=,//g' -e 's/,[a-z0-9_]\+= $//g'`
if (( DEBUG == 1 )); then
        echo "$DATA_BINARY"
fi
curl -i -XPOST 'http://localhost:8086/write?db=rigdata' --data-binary "${DATA_BINARY}"

IFS=$SAVEIFS

