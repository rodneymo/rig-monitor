#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf
. ${BASE_DIR}/lib/functions

# epoch TIME
_TIME=`date +%s`
TIME=$(( ${_TIME} - (${_TIME} % (24 * 60 * 60)) ))

EXPIRED_DATA=$(($TIME - ($DATA_RETENTION * 24 * 60 * 60)))

if [ -f ${BASE_DIR}/run/CLEANUP_LOCK ]; then
    	echo "DB clean up process already running! Exiting..."
	exit
else
        touch  ${BASE_DIR}/run/CLEANUP_LOCK
	LAST_RECORD=$(bookkeeping "LAST_CLEANUP_RECORD")
	#echo $TIME, $LAST_RECORD
	echo "Last cleanup:" `date -d @${LAST_RECORD}` ", ${LAST_RECORD} (EPOCH)"
fi

echo "Data rentetion policy:" $DATA_RETENTION " DAYS"
echo "Today's date:" `date -d @${TIME}` ", ${TIME} (EPOCH)"}
echo "Expired data older than:" `date -d @${EXPIRED_DATA}` ", ${EXPIRED_DATA} (EPOCH)"

DB_TABLES=`awk 'BEGIN {FS = "[ .(]"}; /CREATE TABLE/ { print $7 }' sql/create_db.sql | grep -v -e "info_" -e "_pay" `

for TABLE in $DB_TABLES; do

	EXPIRED_DATA_SQL="DELETE FROM $TABLE WHERE UNIX_TIMESTAMP(time) < ${EXPIRED_DATA};"
	echo "SQL to remove expired data from $TABLE: ${EXPIRED_DATA_SQL}"
	echo $EXPIRED_DATA_SQL | mysql -v -v -u ${GRAFANA_DB_USER} -p${GRAFANA_DB_PWD}  --local-infile rigdata

done

#archive old status and info files
while (( LAST_RECORD < TIME )); do
	if [ "$DATE_FORMAT" == "MMDDYYYY" ]; then
		_LAST_RECORD=`date -d @${LAST_RECORD} +%m-%d-%Y`
	else
		_LAST_RECORD=`date -d @${LAST_RECORD} +%d-%m-%Y`
	fi
	
	echo -n "Older files up to ${_LAST_RECORD} will be archived..."

	if ls ${DATA_DIR}/*${_LAST_RECORD}.csv 1> /dev/null 2>&1; then
		tar --remove-files -czvf ${DATA_BKUP}/data_files_${_LAST_RECORD}.tar.gz ${DATA_DIR}/*${_LAST_RECORD}.csv
		echo "Files archived and removed!"
	else
		echo "No files found!"
	fi

	LAST_RECORD=$(( LAST_RECORD + ( 24 * 60 * 60 ) ))
done 

$(bookkeeping "LAST_CLEANUP_RECORD" ${LAST_RECORD})

rm ${BASE_DIR}/run/CLEANUP_LOCK

