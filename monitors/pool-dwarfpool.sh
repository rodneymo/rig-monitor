#!/bin/bash

. ${BASE_DIR}/lib/functions

# epoch RUN_TIME
RUN_TIME=`date +%s%N`

SAVEIFS=$IFS
		
######################## DWARFPOOL POOL ########################

echo -n "Querying $LABEL pool..." 

############ Query dashboarddata  ############
#curl "http://dwarfpool.com/eth/api?wallet=0x2257e0c8c24b6d1e50a5c1f5ce67f890adb2585c"
API_URL="${BASE_API_URL}/${CRYPTO,,}/api?wallet=${WALLET_ADDR}"
CURL_OUTPUT=`curl -s "${API_URL}"`
if (( DEBUG == 1 )); then
        echo "curl \"$API_URL\""
        echo $CURL_OUTPUT | jq -r '.'
fi


CURL_OUTPUT_ERROR=`echo $CURL_OUTPUT | jq -r '.error' `
if [ "$CURL_OUTPUT_ERROR" == "true" ]; then
        echo "ERROR QUERYING POOL!"
else
	############ Process stats  ############
        MEASUREMENT="pool_stats"
        TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
        FIELDS=`echo $CURL_OUTPUT | jq -r '. | "total_hashrate=\(.total_hashrate),total_hashrate_calculated=\(.total_hashrate_calculated)"
        LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
        DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
  "last_payment_amount": "0.53641168", 
  "last_payment_date": "Thu, 21 Sep 2017 17:59:01 GMT", 

	############ Process payments  ############
        MEASUREMENT="pool_payments"
        TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
        FIELDS_AND_DATE=`echo $CURL_OUTPUT | jq '.getdashboarddata.data.recent_credits[] | "amount=\(.amount) \(.date)"' | sed 's/\"//g'`

        while read AMOUNT _DATE; do
		DATE_EPOCH=`date --date="${_DATE}" +%s`
		LINE="${MEASUREMENT},${TAGS} ${AMOUNT} ${DATE_EPOCH}000000"
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
        done <<< "$FIELDS_AND_DATE"
fi

echo "done"

# Write to DB
if (( DEBUG == 1 )); then
	echo "$DATA_BINARY"
fi 
curl -i -XPOST 'http://localhost:8086/write?db=rigdata' --data-binary "${DATA_BINARY}"

IFS=$SAVEIFS

