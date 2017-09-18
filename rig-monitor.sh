#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf
. ${BASE_DIR}/lib/functions

# epoch TIME
TIME=`date +%s%N`

if [ -f ${BASE_DIR}/run/RIG_LOCK ]; then
    	echo "rig-monitor process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/RIG_LOCK
fi

for ARGUMENT in "$@"; do
	if [ "$ARGUMENT" == "-trace" ]; then
		set -x
	elif [[ $ARGUMENT =~ ^-r[0-9]+ ]]; then
		DEBUG=1
		L_INDEX=${ARGUMENT:2}
		RIG_LIST=("${RIG_LIST[@]:$L_INDEX:1}")
	else
		echo "Argument unknonw: ${ARGUMENT}"
		rm ${BASE_DIR}/run/RIG_LOCK 
		exit
	fi
done

SAVEIFS=$IFS

# Collect rig data from claymore and smart plug (if enabled)
for RIG_LINE in "${RIG_LIST[@]}"
do
	if (( DEBUG == 1 )); then
		echo $RIG_LINE
	fi

	
	IFS=$',' read RIG_NAME RIG_IP PLUG_IP INSTALLED_GPUS TARGET_HR_ETH TARGET_HR_DCOIN MAX_TEMP MAX_POWER <<<${RIG_LINE}
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

done 

IFS=$SAVEIFS
rm ${BASE_DIR}/run/RIG_LOCK

