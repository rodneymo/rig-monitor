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
		echo $CURL_OUTPUT | jq -r --arg price $PRICE --arg volume $VOLUME --arg market $MARKET --arg currency $QUOTE_CURRENCY '.[] | [.last_updated,.symbol,.name,.price_btc,$currency,.[$price],.[$volume],.[$market]] | @csv' |sed 's/\"//g' >> ${DATA_DIR}/${MARKET_DATA_FILE}
	fi
done

#INGEST COINMARKET  DATA
if [ -f ${DATA_DIR}/${MARKET_DATA_FILE} ] ; then

	echo "ingesting coinmarket data..."

	# sort and remove duplicate entries in DATA file
	sort --field-separator=',' ${DATA_DIR}/${MARKET_DATA_FILE} | uniq > ${DATA_DIR}/${MARKET_DATA_FILE}.tmp
	mv ${DATA_DIR}/${MARKET_DATA_FILE}.tmp ${DATA_DIR}/${MARKET_DATA_FILE}

	BOOKKEEPING_RECORD_NAME="COINMARKET_LAST_RECORD"

	LAST_RECORD=$(bookkeeping $BOOKKEEPING_RECORD_NAME)
	echo "last ingested coinmarket data: $LAST_RECORD"

	# filter out old records using LABEL and LAST_RECORD as filters
       	awk -f ${BASE_DIR}/awk/filter_old_coinmarket_records.awk -v last_record=$LAST_RECORD ${DATA_DIR}/${MARKET_DATA_FILE} > ${TMP_DIR}/coinmarket.tmp

	mysql -vvv -u ${GRAFANA_DB_USER} -p${GRAFANA_DB_PWD}  --local-infile rigdata < ${SQL_SCRIPTS}/ingest_coinmarket_data.sql

	# update bookkeeping file
	$(bookkeeping $BOOKKEEPING_RECORD_NAME $RUN_TIME)
	echo "updating last ingested $LABEL pool stats to: $RUN_TIME"

fi

IFS=$SAVEIFS

rm ${BASE_DIR}/run/COINMARKET_LOCK 

