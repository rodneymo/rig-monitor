#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf

# epoch TIME
TIME=`date +%s`

if [ -f ${BASE_DIR}/run/RIG_LOCK ]; then
    	echo "rig-monitor process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/RIG_LOCK
fi

if [ "$1" == "-trace" ];then
	set -x
fi

SAVEIFS=$IFS

for RIG_LINE in "${RIG_LIST[@]}"
do
	#echo $RIG_LINE
	
	IFS=$',' read RIG_NAME RIG_IP PLUG_IP NUM_GPUS TARGET_HASHRATE TARGET_TEMP TARGET_POWER <<<${RIG_LINE}
	#echo $RIG_IP
	
	# load and capture claymore's http status page 
	CLAYMORE_READOUT=`timeout 5s w3m -dump -cols 1000 http://${RIG_IP}:3333 | awk -vRS= 'END{print}'`
	#echo "$TIME $CLAYMORE_READOUT"

	if [ "$SMART_PLUGS" == "1" ];then
		# read power usage from smart plug
		POWER_USAGE=`${BASE_DIR}/lib/tplink-smartplug.py -t ${PLUG_IP} -j '{"emeter":{"get_realtime":{}}}' | grep Received | sed 's/.*power\":\(\w\+\).*/\1/'`
	else
		POWER_USAGE=0
	fi
	#echo $RIG_NAME, $POWER_USAGE

	awk -f ${BASE_DIR}/awk/filter_claymore_miner_stats.awk -v time=${TIME} rig_name=${RIG_NAME} power_usage=${POWER_USAGE} <<< "$CLAYMORE_READOUT" >> ${DATA_DIR}/${STATUS_DATA_FILE}

done 

#################
fi

if [ -f ${DATA_DIR}/${STATUS_DATA_FILE} ]; then

        echo "ingesting claymore status data..."
        LAST_RECORD=$(bookkeeping "LAST_INGESTED_CLAYMORE_STATUS")
        echo "last ingested status record: $LAST_RECORD"

	# filter out old records
	awk -f ${BASE_DIR}/utils/filter_status_records.awk -v last_record=$LAST_INGESTED_RECORD record_type=RIG ${DATA_DIR}/${STATUS_DATA_FILE} > ${TMP_DIR}/rig_status.tmp
	awk -f ${BASE_DIR}/utils/filter_status_records.awk -v last_record=$LAST_INGESTED_RECORD record_type=GPU ${DATA_DIR}/${STATUS_DATA_FILE} > ${TMP_DIR}/gpu_status.tmp
	# INSERT STATUS DATA INTO DB	
	mysql -u ${GRAFANA_DB_USER} -p${GRAFANA_DB_PWD}  --local-infile rigdata < ${SQL_SCRIPTS}/ingest_status_data.sql

	LAST_INGESTED_RECORD=`tail -1 ${DATA_DIR}/${STATUS_DATA_FILE} | cut -d',' -f 2`
	echo $LAST_INGESTED_RECORD > ${BASE_DIR}/run/INGEST_BOOKEEPER.log

	# update bookkeeping file
	LAST_RECORD=`tail -1 ${DATA_DIR}/${STATUS_DATA_FILE} | cut -d',' -f 2`
	$(bookkeeping "LAST_INGESTED_CLAYMORE_STATUS" ${LAST__RECORD})
	echo "updating last ingested claymore status record to: $LAST_RECORD"
fi

IFS=$SAVEIFS

rm ${BASE_DIR}/run/RIG_LOCK

