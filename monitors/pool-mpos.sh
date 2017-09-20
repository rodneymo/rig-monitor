#!/bin/bash

. ${BASE_DIR}/lib/functions

# epoch RUN_TIME
RUN_TIME=`date +%s%N`

SAVEIFS=$IFS
		
######################## MPOS POOL ########################

echo -n "Querying $LABEL pool..." 

############ Query dashboarddata  ############
DASHBOARD_URL="${BASE_API_URL}/index.php?page=api&action=getdashboarddata&api_key=${API_TOKEN}"
CURL_OUTPUT=`curl -s "${DASHBOARD_URL}"`
if (( DEBUG == 1 )); then
        echo "curl \"$DASHBOARD_URL\""
        echo $CURL_OUTPUT | jq -r '.'
fi

if [ "$CURL_OUTPUT" == "Access denied" ]; then
        echo "NO DATA FOUND"
else
	############ Process stats  ############
        MEASUREMENT="pool_stats"
        TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},api_token=${API_TOKEN},wallet_addr=${WALLET_ADDR}"
        FIELDS=`echo $CURL_OUTPUT | jq -r '.getdashboarddata.data | "hashrate=\(.raw.personal.hashrate),pool_hashrate=\(.raw.pool.hashrate),network_hashrate=\(.raw.network.hashrate),valid_shares=\(.personal.shares.valid),invalid_shares=\(.personal.shares.invalid),unpaid_shares=\(.personal.shares.unpaid),balance_confirmed=\(.balance.confirmed),balance_unconfirmed=\(.balance.unconfirmed)"' `
        LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
        DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"

	############ Process payments  ############
        MEASUREMENT="pool_payments"
        TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},api_token=${API_TOKEN},wallet_addr=${WALLET_ADDR}"
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

