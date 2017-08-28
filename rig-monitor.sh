#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf

# epoch TIME
TIME=`date +%s`

if [ -f ${BASE_DIR}/run/LOCK ]; then
    	echo "rig-monitor process still running! Exiting..."
	exit
elif [ -f ${BASE_DIR}/run/INGEST_LOCK ]; then
    	echo "ingest process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/LOCK
fi

SAVEIFS=$IFS

for RIG_LINE in "${RIG_LIST[@]}"
do
	#echo $RIG_LINE
	
	IFS=$',' read RIG_NAME RIG_IP PLUG_IP NUM_GPUS TARGET_HASHRATE TARGET_TEMP TARGET_POWER <<<${RIG_LINE}
	#echo $RIG_IP
	
	# load and capture claymore's http status page 
	CLAYMORE_READOUT=`timeout 5s w3m -dump -cols 1000 http://${RIG_IP}:3333 | awk -vRS= 'END{print}'`
	#echo "$TIME $CLAYMORE_READOUT" >> ${BASE_DIR}/LOG_DIR/rig_monitor.trace  # This is needed to presever the newlines characters

	if [ "$SMART_PLUGS" == "1" ];then
		# read power usage from smart plug
		POWER_USAGE=`${BASE_DIR}/utils/tplink-smartplug.py -t ${PLUG_IP} -j '{"emeter":{"get_realtime":{}}}' | grep Received | sed 's/.*power\":\(\w\+\).*/\1/'`
	else
		POWER_USAGE=0
	fi
	#echo $RIG_NAME, $POWER_USAGE

	awk -f ${BASE_DIR}/utils/parse_status_data.awk -v time=${TIME} rig_name=${RIG_NAME} power_usage=${POWER_USAGE} <<< "$CLAYMORE_READOUT" >> ${DATA_DIR}/${STATUS_DATA_FILE}

done 
IFS=$SAVEIFS

${BASE_DIR}/ingest-data.sh

rm ${BASE_DIR}/run/LOCK

