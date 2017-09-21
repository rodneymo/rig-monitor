#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/lib/functions

# epoch TIME
TIME=`date +%s%N`

echo "collecting data from $RIG_NAME..."
	
# load and capture claymore's http status page 
CLAYMORE_READOUT=`timeout 5s w3m -dump -cols 1000 http://${RIG_IP}:3333 | awk -vRS= 'END{print}'`
if (( DEBUG == 1 )); then
	echo "$TIME $CLAYMORE_READOUT"
fi

if [ "$SMART_PLUGS" == "1" ];then
	# read power usage from smart plug
	POWER_USAGE=`${BASE_DIR}/lib/tplink-smartplug.py -t ${PLUG_IP} -j '{"emeter":{"get_realtime":{}}}' | grep Received | sed 's/.*power\":\(\w\+\).*/\1/'`
else
		POWER_USAGE=0
fi
if (( DEBUG == 1 )); then
	echo $RIG_NAME, $POWER_USAGE
fi


# parse miner output, prepare data for influxdb ingest and filter out null tags, fields
DATA_POINTS=`awk -f ${BASE_DIR}/awk/parse_claymore_status.awk \
	-v time=${TIME} rig_name=${RIG_NAME} installed_gpus=${INSTALLED_GPUS} target_hr_eth=${TARGET_HR_ETH} target_hr_dcoin=${TARGET_HR_DCOIN} \
	max_power=${MAX_POWER} power_usage=${POWER_USAGE} gpu_max_temp=${MAX_TEMP} \
	<<< "$CLAYMORE_READOUT" `
DATA_BINARY=`echo "${DATA_POINTS}" |  sed -e 's/[a-z0-9_]\+=,//g' -e 's/,[a-z0-9_]\+= $//g'`
if (( DEBUG == 1 )); then
        echo "$DATA_BINARY"
fi
curl -i -XPOST 'http://localhost:8086/write?db=rigdata' --data-binary "${DATA_BINARY}"

IFS=$SAVEIFS
rm ${BASE_DIR}/run/RIG_LOCK

