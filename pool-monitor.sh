#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf
. ${BASE_DIR}/utils/functions

# epoch TIME
TIME=`date +%s`

if [ -f ${BASE_DIR}/run/POOL_LOCK ]; then
    	echo "pool-monitor process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/POOL_LOCK
fi

if [ "$1" == "-trace" ];then
	set -x
fi

SAVEIFS=$IFS

# FETCH POOL DATA VIA HTTP
for POOL_LINE in "${POOL_WALLET_LIST[@]}"
do
	IFS=$',' read POOL_NAME WALLET_ADDR <<<${POOL_LINE}
	#echo $POOL_NAME $WALLET_ADDR 

	if [ "$POOL_NAME" == "ETHERMINE" ]; then
		BASE_API='https://api.ethermine.org'
		STATS_URL="${BASE_API}/miner/${WALLET_ADDR}/currentStats"
		#echo $STATS_URL
		PAYOUT_URL="${BASE_API}/miner/${WALLET_ADDR}/payouts"
		#echo $PAYOUT_URL

		curl -s "${STATS_URL}" | jq -r '.data | [.time,.lastSeen,.reportedHashrate,.currentHashrate,.validShares,.invalidShares,.staleShares,.averageHashrate,.activeWorkers,.unpaid,.unconfirmed,.coinsPerMin,.usdPerMin,.btcPerMin] | @csv' >> ${DATA_DIR}/$ETHERMINE_STATS_DATA_FILE
		curl -s "${PAYOUT_URL}" | jq -r '.data[] | [.paidOn,.start,.end,.amount,.txHash] | @csv' >> ${DATA_DIR}/$ETHERMINE_PAYOUTS_DATA_FILE


	fi
done

# INGEST POOL DATA
if [ -f ${DATA_DIR}/${ETHERMINE_STATS_DATA_FILE} ] && [ -f ${DATA_DIR}/${ETHERMINE_PAYOUTS_DATA_FILE} ] ; then
	echo "ingesting pool data..."
	LAST_STATS_RECORD=$(bookkeeping "LAST_INGESTED_ETHERMINE_STATS")
	LAST_PAYOUTS_RECORD=$(bookkeeping "LAST_INGESTED_ETHERMINE_PAYOUTS")
	echo "last ingested ethermine pool stats: $LAST_STATS_RECORD"
	echo "last ingested ethermine pool payout: $LAST_PAYOUTS_RECORD"

	# sort and remove old entries
	sort --field-separator=',' ${DATA_DIR}/${ETHERMINE_STATS_DATA_FILE} | uniq > ${DATA_DIR}/${ETHERMINE_STATS_DATA_FILE}.tmp
	mv ${DATA_DIR}/${ETHERMINE_STATS_DATA_FILE}.tmp ${DATA_DIR}/${ETHERMINE_STATS_DATA_FILE}
	# filter out old records
        awk -f ${BASE_DIR}/utils/filter_old_records.awk -v last_record=$LAST_STATS_RECORD ${DATA_DIR}/${ETHERMINE_STATS_DATA_FILE} > ${TMP_DIR}/ethermine_stats.tmp

	# sort and remove old entries
	sort --field-separator=',' ${DATA_DIR}/${ETHERMINE_PAYOUTS_DATA_FILE} | uniq > ${DATA_DIR}/${ETHERMINE_PAYOUTS_DATA_FILE}.tmp
	mv ${DATA_DIR}/${ETHERMINE_PAYOUTS_DATA_FILE}.tmp ${DATA_DIR}/${ETHERMINE_PAYOUTS_DATA_FILE}
	# filter out old records
        awk -f ${BASE_DIR}/utils/filter_old_records.awk -v last_record=$LAST_PAYOUTS_RECORD ${DATA_DIR}/${ETHERMINE_PAYOUTS_DATA_FILE} > ${TMP_DIR}/ethermine_payouts.tmp

	# insert data into DB
	mysql -vvv -u ${GRAFANA_DB_USER} -p${GRAFANA_DB_PWD}  --local-infile rigdata < ${SQL_SCRIPTS}/ingest_ethermine_data.sql


	# update bookkeeping file
	LAST_STATS_RECORD=`tail -1 ${DATA_DIR}/${ETHERMINE_STATS_DATA_FILE} | cut -d',' -f 1`
	$(bookkeeping "LAST_INGESTED_ETHERMINE_STATS" ${LAST_STATS_RECORD})
	echo "updating last ingested ethermine pool stats to: $LAST_STATS_RECORD"

	# update bookkeeping file
	LAST_PAYOUTS_RECORD=`tail -1 ${DATA_DIR}/${ETHERMINE_PAYOUTS_DATA_FILE} | cut -d',' -f 1`
	$(bookkeeping "LAST_INGESTED_ETHERMINE_PAYOUTS" ${LAST_PAYOUTS_RECORD})
	echo "updating last ingested ethermine pool payout to: $LAST_PAYOUTS_RECORD"
fi

IFS=$SAVEIFS

rm ${BASE_DIR}/run/POOL_LOCK 

