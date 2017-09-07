#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf
. ${BASE_DIR}/lib/functions

# epoch RUN_TIME
RUN_TIME=`date +%s`

if [ -f ${BASE_DIR}/run/COINMARKET_LOCK ]; then
    	echo "coinmarket process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/COINMARKET_LOCK
fi

if [ "$1" == "-trace" ];then
	set -x
fi

SAVEIFS=$IFS

# FETCH MARKET DATA VIA COINMARKET API
for COIN_LINE in "${COIN_LIST[@]}"
do
	IFS=$',' read BASE_CURRENCY QUOTE_CURRENCY <<<${COIN_LINE}
	#echo $BASE_CURRENCY $QUOTE_CURRENCY

	COIN_URL="https://api.coinmarketcap.com/v1/ticker/${BASE_CURRENCY}/"
	if [ "$QUOTE_CURRENCY" != "USD" ]; then
		COIN_URL="${COIN_URL}?convert=${QUOTE_CURRENCY}"
	fi
	echo $COIN_URL
	CURL_OUTPUT=`curl -s "${COIN_URL}" | jq -r '.'`
	#echo $CURL_OUTPUT

        CURL_STATUS=`echo $CURL_OUTPUT | jq -r '.error?'`
        #echo $CURL_STATUS
        if [ "$CURL_STATUS" == "id not found" ]; then
                echo "$BASE_CURRENCY DOES NOT EXIST. PLEASE CHECK CONF FILE"
	else
		PRICE="price_${QUOTE_CURRENCY,,}"
		VOLUME="24h_volume_${QUOTE_CURRENCY,,}"
		MARKET="market_cap_${QUOTE_CURRENCY,,}"
		echo $CURL_OUTPUT | jq -r --arg price $PRICE --arg volume $VOLUME --arg market $MARKET --arg currency $QUOTE_CURRENCY '.[] | [.symbol,.name,.price_btc,$currency,.[$price],.[$volume],.[$market]] | @csv'
	fi
done

rm ${BASE_DIR}/run/COINMARKET_LOCK 
exit

#INGEST POOL DATA
if [ -f ${DATA_DIR}/${POOL_DATA_FILE} ] ; then

	echo "ingesting pool data..."

	# sort and remove duplicate entries in DATA file
	sort --field-separator=',' ${DATA_DIR}/${POOL_DATA_FILE} | uniq > ${DATA_DIR}/${POOL_DATA_FILE}.tmp
	mv ${DATA_DIR}/${POOL_DATA_FILE}.tmp ${DATA_DIR}/${POOL_DATA_FILE}

	for POOL_LINE in "${POOL_LIST[@]}"; do
		IFS=$',' read POOL_TYPE LABEL BASE_API_URL API_TOKEN WALLET_ADDR <<<${POOL_LINE}

		BOOKKEEPING_RECORD_NAME="${LABEL}_POOL_LAST_RECORD"

		LAST_RECORD=$(bookkeeping $BOOKKEEPING_RECORD_NAME)
		echo "last ingested $LABEL pool stats: $LAST_RECORD"

		if [ "$POOL_TYPE" == "ETHERMINE" ]; then
			# filter out old records using LABEL and LAST_RECORD as filters
       			awk -f ${BASE_DIR}/awk/filter_pool_records_by_tag.awk -v label=$LABEL report=currentStats last_record=$LAST_RECORD ${DATA_DIR}/${POOL_DATA_FILE} > ${TMP_DIR}/${POOL_TYPE}_ethermine_stats.tmp
       			awk -f ${BASE_DIR}/awk/filter_pool_records_by_tag.awk -v label=$LABEL report=payouts last_record=$LAST_RECORD ${DATA_DIR}/${POOL_DATA_FILE} > ${TMP_DIR}/${POOL_TYPE}_ethermine_payouts.tmp

			mysql -vvv -u ${GRAFANA_DB_USER} -p${GRAFANA_DB_PWD}  --local-infile rigdata < ${SQL_SCRIPTS}/ingest_ethermine_data.sql
		fi

		# update bookkeeping file
		$(bookkeeping $BOOKKEEPING_RECORD_NAME $RUN_TIME)
		echo "updating last ingested $LABEL pool stats to: $RUN_TIME"
	done




fi

IFS=$SAVEIFS

rm ${BASE_DIR}/run/COINMARKET_LOCK 

