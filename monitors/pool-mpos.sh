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
	############ pool stats  ############
        MEASUREMENT="pool_stats"
        TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
        FIELDS=`echo $CURL_OUTPUT | jq -r '.getdashboarddata.data | "hr=\(.raw.personal.hashrate),valid_shares=\(.personal.shares.valid),invalid_shares=\(.personal.shares.invalid),unpaid_shares=\(.personal.shares.unpaid),balance_confirmed=\(.balance.confirmed),balance_unconfirmed=\(.balance.unconfirmed)"' `
        LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
        DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"

	############ network stats  ############
        MEASUREMENT="network_stats"
        TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
        FIELDS=`echo $CURL_OUTPUT | jq -r '.getdashboarddata.data | "pool_hr=\(.raw.pool.hashrate),network_hr=\(.raw.network.hashrate),difficulty=\(.network.difficulty),esttimeperblock=\(.network.esttimeperblock)"' `
        LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
        DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"

	############ payments stats ############
        MEASUREMENT="pool_payments"
        TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
        FIELDS_AND_DATE=`echo $CURL_OUTPUT | jq '.getdashboarddata.data.recent_credits[] | "amount=\(.amount) \(.date)"' | sed 's/\"//g'`

        while read AMOUNT _DATE; do
		DATE_EPOCH=`date --date="${_DATE}" +%s`
		LINE="${MEASUREMENT},${TAGS} ${AMOUNT} ${DATE_EPOCH}000000000"
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
        done <<< "$FIELDS_AND_DATE"
fi

############ Query workers ############
WORKERS_URL="${BASE_API_URL}/index.php?page=api&action=getuserworkers&api_key=${API_TOKEN}"
WORKERS_OUTPUT=`curl -s "${WORKERS_URL}" | jq -r '.'`

if (( DEBUG == 1 )); then
	echo "curl \"$WORKERS_URL\""
	echo $WORKERS_OUTPUT  | jq -r '.'
fi

if [ "$WORKERS_OUTPUT" == "Access denied" ]; then
        echo "NO DATA FOUND"
else
	MEASUREMENT="workers_stats"
	WORKER_TAG_AND_FIELDS=`echo $WORKERS_OUTPUT | jq -r '.getuserworkers.data[] | "worker_id=\(.username) current_hr=\(.hashrate)"' | sed -s 's/[0-9a-zA-Z]*\.//' `
	while read -r WORKER_TAG FIELDS; do
		TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},${WORKER_TAG}"
		LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${DATE_EPOCH}000000000"
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
	done<<< "$WORKER_TAG_AND_FIELDS"
fi


echo "done"

# Write to DB
if (( DEBUG == 1 )); then
	echo "$DATA_BINARY"
fi 

IFS=$SAVEIFS

