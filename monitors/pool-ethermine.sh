#!/bin/bash

. ${BASE_DIR}/lib/functions

# epoch RUN_TIME
RUN_TIME=`date +%s%N`

SAVEIFS=$IFS

case "$CRYPTO"  in
	ETH) BASE_API_URL="https://api.ethermine.org"
    	;;
	ETC) BASE_API_URL="https://api-etc.ethermine.org"
    	;;
	ZEC) BASE_API_URL="https://api-zcash.flypool.org"
    	;;
esac

if (( DEBUG == 1 )); then
	echo "BASE API: ${BASE_API_URL}"
fi
######################## ETHERMINE POOL ########################

echo -n "Querying $LABEL pool..." 

############ Query currentStats ############

STATS_URL="${BASE_API_URL}/miner/${WALLET_ADDR}/currentStats"
STATS_OUTPUT=`curl -s "${STATS_URL}" | jq -r '.data'`

if (( DEBUG == 1 )); then
	echo "curl \"$STATS_URL\""
	echo $STATS_OUTPUT | jq -r '.'
fi

if [ "$STATS_OUTPUT" == "NO DATA" ]; then
	echo "NO DATA FOUND"
else
	MEASUREMENT="pool_stats"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	FIELDS_AND_TIME=`echo $STATS_OUTPUT | jq -r '. | "reported_hr=\(.reportedHashrate),hr=\(.currentHashrate),valid_shares=\(.validShares),invalid_shares=\(.invalidShares),stale_shares=\(.staleShares),avg_hr_24h=\(.averageHashrate),active_workers=\(.activeWorkers),unpaid=\(.unpaid),unconfirmed=\(.unconfirmed),coinsPerMin=\(.coinsPerMin),usdPerMin=\(.usdPerMin),btcPerMin=\(.btcPerMin) \(.time)000000000"' | sed 's/null/0/g' `
	LINE="${MEASUREMENT},${TAGS} ${FIELDS_AND_TIME}"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
fi

############ Query networkStats ############
NETWORK_URL="${BASE_API_URL}/networkStats"
NETWORK_OUTPUT=`curl -s "${NETWORK_URL}" | jq -r '.'`

if (( DEBUG == 1 )); then
	echo "curl \"$NETWORK_URL\""
	echo $NETWORK_OUTPUT  | jq -r '.'
fi

API_STATUS=`echo $NETWORK_OUTPUT | jq -r '.status'` 
if [ "$API_STATUS" != "OK" ]; then
	echo "NO DATA FOUND"
else
	MEASUREMENT="network_stats"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	FIELDS_AND_TIME=`echo $NETWORK_OUTPUT | jq -r '.data| "hashrate=\(.hashrate),difficulty=\(.difficulty),block_time=\(.blockTime) \(.time)000000000"' | sed 's/null/0/g' `
	LINE="${MEASUREMENT},${TAGS} ${FIELDS_AND_TIME}"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
fi

############ Query workers ############
WORKERS_URL="${BASE_API_URL}/miner/${WALLET_ADDR}/workers"
WORKERS_OUTPUT=`curl -s "${WORKERS_URL}" | jq -r '.'`

if (( DEBUG == 1 )); then
	echo "curl \"$WORKERS_URL\""
	echo $WORKERS_OUTPUT  | jq -r '.'
fi

API_STATUS=`echo $WORKERS_OUTPUT | jq -r '.status'` 
if [ "$API_STATUS" != "OK" ]; then
	echo "NO DATA FOUND"
else
	MEASUREMENT="worker_stats"
	WORKER_TAG_FIELDS_AND_TIME=`echo $WORKERS_OUTPUT | jq -r '.data[] | "worker_id=\(.worker) reported_hr=\(.reportedHashrate),current_hr=\(.currentHashrate),valid_shares=\(.validShares),invalid_shares=\(.invalidShares),stale_shares=\(.staleShares),avg_hr_24h=\(.averageHashrate) \(.time)000000000"' `
	while read -r WORKER_TAG FIELDS W_TIME; do
		TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},${WORKER_TAG}"
		LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${W_TIME}"
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
	done<<< "$WORKER_TAG_FIELDS_AND_TIME"
fi

############ Query payouts ############
PAYMENTS_URL="${BASE_API_URL}/miner/${WALLET_ADDR}/payouts"
SQL="SELECT last(amount) from pool_payments where label='"${LABEL}"'"
LAST_RECORD=$(get_last_record "$SQL")
PAYMENT_OUTPUTS=`curl -s "${PAYMENTS_URL}" | jq --arg LAST_RECORD $LAST_RECORD -r '.data[]? | select (.paidOn > ($LAST_RECORD | tonumber))'`

if (( DEBUG == 1 )); then
	echo "Last ingested record: ${LAST_RECORD}"
	echo "curl \"$PAYMENTS_URL\"| jq --arg LAST_RECORD" ${LAST_RECORD} "-r '.data[]? | select (.paidOn > ($LAST_RECORD | tonumber))'"
	echo $PAYMENT_OUTPUTS 
fi
if [ "$PAYMENT_OUTPUTS" == "" ]; then
	echo "NO DATA FOUND"
else
	MEASUREMENT="pool_payments"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	FIELDS_AND_TIME=`echo $PAYMENT_OUTPUTS | jq -r '. | "amount=\(.amount),txHash=\"\(.txHash)\" \(.paidOn)000000000"'`
	while read -r _FIELD; do
		LINE="${MEASUREMENT},${TAGS} ${_FIELD}"
		RECORD_TIME=`echo ${LINE} | awk '{ print substr($NF,1,11) }' `
		if (( RECORD_TIME > LAST_RECORD )) ; then
			LAST_RECORD=${RECORD_TIME}
		fi
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
	done <<< "$FIELDS_AND_TIME"
        if (( DEBUG == 1 )); then
		echo "Updating last ingested processed: ${LAST_RECORD}"
        fi

fi

echo "done"

# Write to DB
if (( DEBUG == 1 )); then
	echo "$DATA_BINARY"
fi 

IFS=$SAVEIFS

