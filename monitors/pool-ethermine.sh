#!/bin/bash

. ${BASE_DIR}/lib/functions

# epoch RUN_TIME
RUN_TIME=`date +%s%N`

SAVEIFS=$IFS

######################## ETHERMINE POOL ########################

echo -n "Querying $LABEL pool..." 

############ Query currentStats ############
STATS_URL="${BASE_API_URL}/miner/${WALLET_ADDR}/currentStats"
CURL_OUTPUT=`curl -s "${STATS_URL}" | jq -r '.data'`

if (( DEBUG == 1 )); then
	echo "curl \"$STATS_URL\""
	echo $CURL_OUTPUT | jq -r '.'
fi

if [ "$CURL_OUTPUT" == "NO DATA" ]; then
	echo "NO DATA FOUND"
else
	MEASUREMENT="pool_stats"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},api_token=${API_TOKEN},wallet_addr=${WALLET_ADDR}"
	FIELDS_AND_TIME=`echo $CURL_OUTPUT | jq -r '. | "reportedHashrate=\(.reportedHashrate),currentHashrate=\(.currentHashrate),validShares=\(.validShares),invalidShares=\(.invalidShares),staleShares=\(.staleShares),averageHashrate=\(.averageHashrate),activeWorkers=\(.activeWorkers),unpaid=\(.unpaid),unconfirmed=\(.unconfirmed),coinsPerMin=\(.coinsPerMin),usdPerMin=\(.usdPerMin),btcPerMin=\(.btcPerMin) \(.time)000000000"' | sed 's/null/0/g' `
	LINE="${MEASUREMENT},${TAGS} ${FIELDS_AND_TIME}"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
fi
		
############ Query payouts ############
PAYOUT_URL="${BASE_API_URL}/miner/${WALLET_ADDR}/payouts"
LAST_RECORD=$(bookkeeping ETHERMINE_PAYOUTS_LAST_RECORD)
CURL_OUTPUT=`curl -s "${PAYOUT_URL}" | jq --arg LAST_RECORD $LAST_RECORD -r '.data[]? | select (.paidOn > ($LAST_RECORD | tonumber))'`

if (( DEBUG == 1 )); then
	echo "Last ingested record: ${LAST_RECORD}"
	echo "curl \"$PAYOUT_URL\""
	echo $CURL_OUTPUT 
fi
if [ "$CURL_OUTPUT" == "" ]; then
	echo "NO DATA FOUND"
else
	MEASUREMENT="pool_payments"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},api_token=${API_TOKEN},wallet_addr=${WALLET_ADDR}"
	FIELDS_AND_TIME=`echo $CURL_OUTPUT | jq -r '. | "amount=\(.amount),txHash=\"\(.txHash)\" \(.paidOn)000000000"'`
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

        $(bookkeeping ETHERMINE_PAYOUTS_LAST_RECORD ${LAST_RECORD})
fi

echo "done"

# Write to DB
if (( DEBUG == 1 )); then
	echo "$DATA_BINARY"
fi 
curl -i -XPOST 'http://localhost:8086/write?db=rigdata' --data-binary "${DATA_BINARY}"

IFS=$SAVEIFS

