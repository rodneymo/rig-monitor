#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf

# epoch TIME
_TIME=`date +%s`
TIME=$(( ${_TIME} - (${_TIME} % (24 * 60 * 60)) ))
echo $TIME

EXPIRED_DATA=$(($TIME - ($DATA_RETENTION * 24 * 60 * 60)))

echo "Data rentetion policy:" $DATA_RETENTION " DAYS"
echo "Latest data:" `date -d @${TIME}` ", ${TIME} (EPOCH)"}
echo "Expired data:" `date -d @${EXPIRED_DATA}` ", ${EXPIRED_DATA} (EPOCH)"


if [ -f ${BASE_DIR}/run/CLEANUP_LOCK ]; then
    	echo "DB clean up process already running! Exiting..."
	exit
else
        touch  ${BASE_DIR}/run/CLEANUP_LOCK
        if [ ! -f ${BASE_DIR}/run/CLEANUP_BOOKEEPER.log ]; then
               	echo "1502928000" > ./run/CLEANUP_BOOKEEPER.log 
	fi
	LAST_CLEANUP=`cat ${BASE_DIR}/run/CLEANUP_BOOKEEPER.log`
	echo "Last cleanup:" `date -d @${LAST_CLEANUP}` ", ${LAST_CLEANUP} (EPOCH)"
fi

#  PURGE OLD DATA FROM DB
EXPIRED_RIG_DATA_SQL="DELETE FROM status_rig WHERE UNIX_TIMESTAMP(time) < ${EXPIRED_DATA};"
EXPIRED_GPU_DATA_SQL="DELETE FROM status_gpu WHERE UNIX_TIMESTAMP(time) < ${EXPIRED_DATA};"
echo "SQL TO REMOVE EXPIRED RIG_STATUS DATA: $EXPIRED_RIG_DATA_SQL"
echo "SQL TO REMOVE EXPIRED GPU_STATUS DATA: $EXPIRED_GPU_DATA_SQL"
echo $EXPIRED_RIG_DATA_SQL | mysql -v -v -u ${GRAFANA_DB_USER} -p${GRAFANA_DB_PWD}  --local-infile rigdata
echo $EXPIRED_GPU_DATA_SQL | mysql -v -v -u ${GRAFANA_DB_USER} -p${GRAFANA_DB_PWD}  --local-infile rigdata

#archive old status and info files
while (( LAST_CLEANUP < TIME )); do
	if [ "$DATE_FORMAT" == "MMDDYYYY" ]; then
		_LAST_CLEANUP=`date -d @${LAST_CLEANUP} +%m-%d-%Y`
	else
		_LAST_CLEANUP=`date -d @${LAST_CLEANUP} +%d-%m-%Y`
	fi
	
	OLD_INFO_DATA_FILE="info_data_${_LAST_CLEANUP}.csv"
	OLD_STATUS_DATA_FILE="status_data_${_LAST_CLEANUP}.csv"
	echo "${OLD_INFO_DATA_FILE} will be archived"
	echo "${OLD_STATUS_DATA_FILE} will be archived"

	if [ -f ${DATA_DIR}/${OLD_STATUS_DATA_FILE} ] || [ -f ${DATA_DIR}/${OLD_INFO_DATA_FILE} ] ; then
		tar --remove-files -czvf ${DATA_BKUP}/data_files_${_LAST_CLEANUP}.tar.gz ${DATA_DIR}/*${_LAST_CLEANUP}.csv
		echo "Files ${DATA_DIR}/${OLD_STATUS_DATA_FILE} and ${DATA_DIR}/${OLD_INFO_DATA_FILE} archived and removed!"
	else
		echo "Files not found!"
	fi
	LAST_CLEANUP=$(( LAST_CLEANUP + ( 24 * 60 * 60 ) ))
done 

echo "$LAST_CLEANUP" > ${BASE_DIR}/run/CLEANUP_BOOKEEPER.log

rm ${BASE_DIR}/run/CLEANUP_LOCK

