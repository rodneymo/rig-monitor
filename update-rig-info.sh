#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf

# epoch TIME
TIME=`date +%s`

if [ -f ${BASE_DIR}/run/UPDATE_LOCK ]; then
    	echo "update rig info process already running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/UPDATE_LOCK
	if [ -f ${DATA_DIR}/${INFO_DATA_FILE} ]; then
		rm ${DATA_DIR}/${INFO_DATA_FILE}
	fi
fi


SAVEIFS=$IFS

for RIG_LINE in "${RIG_LIST[@]}"
do
	echo "RIG,"${RIG_LINE} >> ${DATA_DIR}/${INFO_DATA_FILE}
	
	IFS=$',' read RIG_NAME RIG_IP PLUG_IP NUM_GPUS TARGET_HASHRATE TARGET_TEMP TARGET_POWER <<<${RIG_LINE}
	#echo $RIG_IP
	
	# load and capture claymore's http status page 
	CLAYMORE_READOUT=`timeout 5s w3m -dump -cols 1000 http://${RIG_IP}:3333 | awk -vRS= 'END{print}'`
	#echo "$CLAYMORE_READOUT" # This is needed to presever the newlines characters

	awk -f ${BASE_DIR}/awk/parse_claymore_gpu_info.awk -v rig_name=${RIG_NAME} <<< "$CLAYMORE_READOUT" >> ${DATA_DIR}/${INFO_DATA_FILE}
done 

if [ -f ${DATA_DIR}/${INFO_DATA_FILE} ]; then
	
	grep -e '^RIG' ${DATA_DIR}/${INFO_DATA_FILE} | cut -d',' -f 2- > ${TMP_DIR}/rig_info.tmp
	grep -e '^GPU' ${DATA_DIR}/${INFO_DATA_FILE} | cut -d',' -f 2- > ${TMP_DIR}/gpu_info.tmp
	# INSERT INFO DATA INTO DB	
	mysql -u ${GRAFANA_DB_USER} -p${GRAFANA_DB_PWD}  --local-infile rigdata < ${SQL_SCRIPTS}/update_info_data.sql
fi

IFS=$SAVEIFS

rm ${BASE_DIR}/run/UPDATE_LOCK

