#!/bin/bash

. ${BASE_DIR}/lib/functions

# epoch RUN_TIME
RUN_TIME=`date +%s%N`

SAVEIFS=$IFS

BASE_API_URL="https://www.litecoinpool.org/api?api_key="

if (( DEBUG == 1 )); then
	echo "BASE API: ${BASE_API_URL}"
fi
######################## NANOPOOL ########################

echo -n "Querying $LABEL pool..." 
  
############ Query generalinfo API ############

GENERALINFO_URL="${BASE_API_URL}${API_TOKEN}"
GENERALINFO_OUTPUT=`curl -s -m 10 "${GENERALINFO_URL}" | jq -r '.'`

if (( DEBUG == 1 )); then
	echo "curl \"$GENERALINFO_URL\""
	echo $GENERALINFO_OUTPUT | jq -r '.'
fi

API_STATUS=`echo $GENERALINFO_OUTPUT | jq -r '.status'`
if [ "$API_STATUS" == "false" ]; then
		echo "NO DATA FOUND"
else
	MEASUREMENT="pool_stats"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	FIELDS=`echo $GENERALINFO_OUTPUT | jq -r '.user | "hr=\(.hash_rate),balance=\(.unpaid_rewards)"' | sed 's/null/0/g' `
	FIELDS2=`echo $GENERALINFO_OUTPUT | jq -r '"active_workers=\(.workers | length)"' | sed 's/null/0/g' `
	LINE="${MEASUREMENT},${TAGS} ${FIELDS},${FIELDS2} ${RUN_TIME}"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"

	# worker stats
	MEASUREMENT="worker_stats"
	WORKER_TAG_AND_FIELDS=`echo $GENERALINFO_OUTPUT | jq -r '.workers | "rig_id=\(keys|.[]) avg_hr_24h=\(.[]|.hash_rate_24h),hr=\(.[]|.hash_rate),shares=\(.[]|.valid_shares),invalid_shares=\(.[]|.invalid_shares),stale_shares=\(.[]|.stale_shares)"' `
	while read -r WORKER_TAG FIELDS; do
		TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},${WORKER_TAG}"
		LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
	done<<< "$WORKER_TAG_AND_FIELDS"

	# network stats
	MEASUREMENT="network_stats"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	FIELDS=`echo $GENERALINFO_OUTPUT | jq -r '.network | "difficulty=\(.difficulty),block_time=\(.time_per_block)"'`
	LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"

fi

echo "done"

# Write to DB
if (( DEBUG == 1 )); then
	echo "$DATA_BINARY"
fi 

IFS=$SAVEIFS


