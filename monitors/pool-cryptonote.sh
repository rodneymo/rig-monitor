#!/bin/bash

. ${BASE_DIR}/lib/functions

# epoch RUN_TIME
RUN_TIME=`date +%s%N`

SAVEIFS=$IFS

if (( DEBUG == 1 )); then
	echo "BASE API: ${BASE_API_URL}"
fi
######################## ETHERMINE POOL ########################

echo -n "Querying $LABEL pool..." 

############ Query pool stats  ############

STATS_URL="${BASE_API_URL}/api/miner/${WALLET_ADDR}/stats"

STATS_OUTPUT=`curl -s "${STATS_URL}" `

if (( DEBUG == 1 )); then
	echo "curl \"$STATS_URL\""
	echo $STATS_OUTPUT | jq -r '.'
fi

if [ "$STATS_OUTPUT" == "false" ]; then
	echo "NO DATA FOUND"
else
	MEASUREMENT="pool_stats"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	FIELDS=`echo $STATS_OUTPUT | jq -r '. | "hr=\(.hash),valid_shares=\(.validShares),invalid_shares=\(.invalidShares),total_hashes=\(.totalHashes),amount_paid=\(.amtPaid),amount_unpaid=\(.amtDue)"' `
	LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
fi


############ Query workers ############
WORKERS_URL="${BASE_API_URL}/api/miner/${WALLET_ADDR}/identifiers"
WORKERS_OUTPUT=`curl -s "${WORKERS_URL}" `

if (( DEBUG == 1 )); then
	echo "curl \"$WORKERS_URL\""
	echo $WORKERS_OUTPUT  | jq -r '.[]'
fi

if [ "$WORKERS_OUTPUT" == "false" ]; then
	echo "NO DATA FOUND"
else
	WORKER_LIST=`echo $WORKERS_OUTPUT | jq -r '.[]'`
	while read -r WORKER_ID; do
		_WORKER_URL="${BASE_API_URL}/api/miner/${WALLET_ADDR}/stats/${WORKER_ID}"
		_WORKER_OUTPUT=`curl -s "${_WORKER_URL}" `
		if (( DEBUG == 1 )); then
			echo "curl \"$_WORKER_URL\""
			echo $_WORKER_OUTPUT  | jq -r '.'
		fi

		MEASUREMENT="worker_stats"
		TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},rig_id=${WORKER_ID}"
		FIELDS=`echo $_WORKER_OUTPUT | jq -r '. | "hr=\(.hash),valid_shares=\(.validShares),invalid_shares=\(.invalidShares),total_hashes=\(.totalHashes)"' | sed 's/null/0/g' `
		LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"

	done<<<"$WORKER_LIST"
fi

############ Query payouts ############
PAYMENTS_URL="${BASE_API_URL}/api/miner/${WALLET_ADDR}/payments"
SQL="SELECT last(amount) from pool_payments where label='"${LABEL}"'"
LAST_RECORD=$(get_last_record "$SQL")
PAYMENT_OUTPUTS=`curl -s "${PAYMENTS_URL}" | jq --arg LAST_RECORD $LAST_RECORD -r '.[]? | select (.ts > ($LAST_RECORD | tonumber))'`

if (( DEBUG == 1 )); then
	echo "Last ingested record: ${LAST_RECORD}"
	echo "curl \"$PAYMENTS_URL\"| jq --arg LAST_RECORD" ${LAST_RECORD} "-r '.[]? | select (.ts > ($LAST_RECORD | tonumber))'"
	echo $PAYMENT_OUTPUTS 
fi
if [ "$PAYMENT_OUTPUTS" == "" ]; then
	echo "NO DATA FOUND"
else
	MEASUREMENT="pool_payments"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	FIELDS_AND_TIME=`echo $PAYMENT_OUTPUTS | jq -r '. | "amount=\(.amount),txHash=\"\(.txnHash)\" \(.ts)000000000"'`
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

