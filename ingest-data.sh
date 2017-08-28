#/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf

# epoch TIME
TIME=`date +%s`

if [ -f ${BASE_DIR}/run/INGEST_LOCK ]; then
    	echo "update rig info process already running! Exiting..."
	exit
else
        touch  ${BASE_DIR}/run/INGEST_LOCK
        if [ ! -f ${BASE_DIR}/run/INGEST_BOOKEEPER.log ]; then
                echo "0" > ${BASE_DIR}/run/INGEST_BOOKEEPER.log
        fi
	LAST_INGESTED_RECORD=`cat ${BASE_DIR}/run/INGEST_BOOKEEPER.log`
	echo "Last record processed at $LAST_INGESTED_RECORD"
fi

if [ -f ${DATA_DIR}/${STATUS_DATA_FILE} ]; then
	# filter out old records
	awk -f ${BASE_DIR}/utils/filter_status_records.awk -v last_record=$LAST_INGESTED_RECORD record_type=RIG ${DATA_DIR}/${STATUS_DATA_FILE} > ${TMP_DIR}/rig_status.tmp
	awk -f ${BASE_DIR}/utils/filter_status_records.awk -v last_record=$LAST_INGESTED_RECORD record_type=GPU ${DATA_DIR}/${STATUS_DATA_FILE} > ${TMP_DIR}/gpu_status.tmp
	# INSERT STATUS DATA INTO DB	
	mysql -u ${GRAFANA_DB_USER} -p${GRAFANA_DB_PWD}  --local-infile rigdata < ${SQL_SCRIPTS}/ingest_status_data.sql

	LAST_INGESTED_RECORD=`tail -1 ${DATA_DIR}/${STATUS_DATA_FILE} | cut -d',' -f 2`
	echo $LAST_INGESTED_RECORD > ${BASE_DIR}/run/INGEST_BOOKEEPER.log
fi

IFS=$SAVEIFS

rm ${BASE_DIR}/run/INGEST_LOCK

