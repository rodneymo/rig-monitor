#!/bin/bash

. ${BASE_DIR}/lib/functions

# epoch RUN_TIME
RUN_TIME=`date +%s%N`

SAVEIFS=$IFS

if [ "$CRYPTO" == "SC" ]; then
	BASE_API_URL="https://api.nanopool.org/v1/sia"
else
	BASE_API_URL="https://api.nanopool.org/v1/${CRYPTO,,}"
fi

if (( DEBUG == 1 )); then
	echo "BASE API: ${BASE_API_URL}"
fi
######################## NANOPOOL ########################

echo -n "Querying $LABEL pool..." 
  
############ Query generalinfo API ############

GENERALINFO_URL="${BASE_API_URL}/user/${WALLET_ADDR}"
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
	FIELDS=`echo $GENERALINFO_OUTPUT | jq -r '.data | "hr=\(.hashrate),avg_hr_1h=\(.avgHashrate.h1),avg_hr_3h=\(.avgHashrate.h3),avg_hr_6h=\(.avgHashrate.h6),avg_hr_12h=\(.avgHashrate.h12),avg_hr_24h=\(.avgHashrate.h24),active_workers=\(.workers | length),balance=\(.balance),unconfirmed_balance=\(.unconfirmed_balance)"' | sed 's/null/0/g' `
	LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
fi

############ Query network stats API ############
# Query average block time
AVERAGEBLOCKTIME_URL="${BASE_API_URL}/network/avgblocktime"
AVERAGEBLOCKTIME_OUTPUT=`curl -s -m 10 "${AVERAGEBLOCKTIME_URL}" | jq -r '.'`

if (( DEBUG == 1 )); then
	echo "curl \"$AVERAGEBLOCKTIME_URL\""
	echo $AVERAGEBLOCKTIME_OUTPUT | jq -r '.'
fi

API_STATUS=`echo $AVERAGEBLOCKTIME_OUTPUT | jq -r '.status'`
if [ "$API_STATUS" == "false" ]; then
		echo "NO DATA FOUND"
else
	AVERAGEBLOCKTIME=`echo $AVERAGEBLOCKTIME_OUTPUT | jq -r '.data'`
fi

# Query block difficulty
BLOCKS_URL="${BASE_API_URL}/blocks/0/1"
BLOCKS_OUTPUT=`curl -s -m 10 "${BLOCKS_URL}" | jq -r '.'`

if (( DEBUG == 1 )); then
	echo "curl \"$BLOCKS_URL\""
	echo $BLOCKS_OUTPUT | jq -r '.'
fi

API_STATUS_2=`echo $BLOCKS_OUTPUT | jq -r '.status'`
if [ "$API_STATUS_2" == "false" ]; then
		echo "NO DATA FOUND"
else
	DIFFICULTY=`echo $BLOCKS_OUTPUT | jq -r '.data[].difficulty'`
fi

if [ "$API_STATUS" == "true" ] && [ "$API_STATUS_2" == "true" ]; then
	MEASUREMENT="network_stats"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	FIELDS="difficulty=${DIFFICULTY},block_time=${AVERAGEBLOCKTIME}"
	LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
fi

############ Query payouts ############
PAYMENTS_URL="${BASE_API_URL}/payments/${WALLET_ADDR}"
LAST_RECORD_SQL="SELECT last(amount) from pool_payments where label='"${LABEL}"'"
LAST_RECORD=`curl -G 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" --data-urlencode "q=${LAST_RECORD_SQL}" | jq -r '.results[0].series[0].values[0][0]' | awk '/^null/ { print 0 }; /[0-9]+/ {print substr($1,1,10) };' `
PAYMENTS_OUTPUT=`curl -s "${PAYMENTS_URL}" | jq --arg LAST_RECORD ${LAST_RECORD} -r '.data[]? | select (.date > ($LAST_RECORD | tonumber))'`

if (( DEBUG == 1 )); then
	echo "Last ingested record: ${LAST_RECORD}"
	echo "curl \"$PAYMENTS_URL\""
	echo $PAYMENTS_OUTPUT 
fi
if [ "$PAYMENTS_OUTPUT" == "" ]; then
	echo "NO DATA FOUND"
else
	MEASUREMENT="pool_payments"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	FIELDS_AND_TIME=`echo $PAYMENTS_OUTPUT | jq -r '. | "amount=\(.amount),txHash=\"\(.txHash)\" \(.date)000000000"'`
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

curl -i -XPOST 'http://localhost:8086/write?db=rigdata' --data-binary "${DATA_BINARY}"

IFS=$SAVEIFS


