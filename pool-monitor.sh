#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf
. ${BASE_DIR}/lib/functions

# epoch RUN_TIME
RUN_TIME=`date +%s%N`

if [ -f ${BASE_DIR}/run/POOL_LOCK ]; then
    	echo "pool-monitor process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/POOL_LOCK
fi

for ARGUMENT in "$@"; do
	if [ "$ARGUMENT" == "-trace" ]; then
		set -x
	elif [[ $ARGUMENT =~ ^-p[0-9]+ ]]; then
		DEBUG=1
		L_INDEX=${ARGUMENT:2}
		POOL_LIST=("${POOL_LIST[@]:$L_INDEX:1}")
	else
		echo "Argument unknonw: ${ARGUMENT}"
		rm ${BASE_DIR}/run/POOL_LOCK 
		exit
	fi
done

SAVEIFS=$IFS

# FETCH POOL DATA VIA HTTP
for POOL_LINE in "${POOL_LIST[@]}"
do
	IFS=$',' read POOL_TYPE CRYPTO LABEL BASE_API_URL API_TOKEN WALLET_ADDR <<<${POOL_LINE}
	if (( DEBUG == 1 )); then
		echo "Pool info in conf file: $POOL_TYPE $LABEL $BASE_API_URL $API_TOKEN $WALLET_ADDR"
	fi
	
	echo -n "Querying $LABEL pool..." 

        ######################## ETHERMINE POOL ########################
	if [ "$POOL_TYPE" == "ETHERMINE" ]; then

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
		

        ######################## MPOS POOL ########################
	elif [ "$POOL_TYPE" == "MPOS" ]; then

                ############ Query dashboarddata. Incl. payouts  ############
		DASHBOARD_URL="${BASE_API_URL}/index.php?page=api&action=getdashboarddata&api_key=${API_TOKEN}"
		CURL_OUTPUT=`curl -s "${DASHBOARD_URL}"`
                if (( DEBUG == 1 )); then
			echo "curl \"$DASHBOARD_URL\""
			echo $CURL_OUTPUT | jq -r '.'
                fi

		if [ "$CURL_OUTPUT" == "Access denied" ]; then
			echo "NO DATA FOUND"
		else
			MEASUREMENT="pool_stats"
			TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},data_type=stats,api_token=${API_TOKEN},wallet_addr=${WALLET_ADDR}"
			FIELDS=`echo $CURL_OUTPUT | jq '.getdashboarddata.data | "hashrate=\(.raw.personal.hashrate),pool_hashrate=\(.raw.pool.hashrate),network_hashrate=\(.raw.network.hashrate),valid_shares=\(.personal.shares.valid),invalid_shares=\(.personal.shares.invalid),unpaid_shares=\(.personal.shares.unpaid),balance_confirmed=\(.balance.confirmed),balance_unconfirmed=\(.balance.unconfirmed)"'`
			
			LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
			DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"

			MEASUREMENT="pool_stats"
			TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},data_type=payouts,api_token=${API_TOKEN},wallet_addr=${WALLET_ADDR}"
			FIELDS_AND_DATE=`echo $CURL_OUTPUT | jq '.getdashboarddata.data.recent_credits[] | "amount=\(.amount) \(.date)"' | sed 's/\"//g'`

			while read AMOUNT _DATE; do
				DATE_EPOCH=`date --date="${_DATE}" +%s`
				LINE="${MEASUREMENT},${TAGS} ${AMOUNT} ${DATE_EPOCH}000000"
				DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
			done <<< "$FIELDS_AND_DATE"
		fi

        ######################## NANOPOOL POOL ########################
	elif [ "$POOL_TYPE" == "NANOPOOL" ]; then

                ############ Query chardata ############
		CHARTDATA_URL="https://api.nanopool.org/v1/${CRYPTO,,}/hashratechart/${WALLET_ADDR}"

		CURL_OUTPUT=`curl -s "${CHARTDATA_URL}"`
                if (( DEBUG == 1 )); then
			echo "curl \"$CHARTDATA_URL\""
			echo $CURL_OUTPUT | jq -r '.data[]'
                fi

		if [ "$CURL_OUTPUT" == "" ]; then
			echo "NO DATA FOUND"
		else
			MEASUREMENT="pool_stats"
			TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},data_type=stats,api_token=${API_TOKEN},wallet_addr=${WALLET_ADDR}"
                        FIELDS_AND_DATE=`echo $CURL_OUTPUT | jq '.data[] | "hashrate=\(.hashrate),shares=\(.shares) \(.date)000000000"' | sed 's/\"//g'`
			#echo $FIELDS_AND_DATE;
                        while read -r _LINE; do
				echo ${_LINE}
                                LINE="${MEASUREMENT},${TAGS} ${_LINE}"
                                DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
                        done <<< "$FIELDS_AND_DATE"
		fi

                ############ Query payments ############
		PAYOUTS_URL="https://api.nanopool.org/v1/${CRYPTO,,}/payments/${WALLET_ADDR}"

		CURL_OUTPUT=`curl -s "${PAYOUTS_URL}"`
                if (( DEBUG == 1 )); then
			echo "curl \"$PAYOUTS_URL\""
			echo $CURL_OUTPUT | jq -r '.data[]'
                fi

		if [ "$CURL_OUTPUT" == "" ]; then
			echo "NO DATA FOUND"
		else
			MEASUREMENT="pool_stats"
			TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},data_type=payouts,api_token=${API_TOKEN},wallet_addr=${WALLET_ADDR}"
                        FIELDS_AND_DATE=`echo $CURL_OUTPUT | jq '.data[] | "amount=\(.amount),txHash=\"\(.txHash)\" \(.date)000000000"' `
			echo $FIELDS_AND_DATE;
                        while read -r _LINE; do
				echo ${_LINE}
                                LINE="${MEASUREMENT},${TAGS} ${_LINE}"
                                DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
                        done <<< "$FIELDS_AND_DATE"
		fi

                ############ Query block stats ############
		BLOCK_STATS_URL="https://api.nanopool.org/v1/${CRYPTO,,}/block_stats/0/50"

                CURL_OUTPUT=`curl -s "${BLOCK_STATS_URL}"`
                if (( DEBUG == 1 )); then
                        echo "curl \"$BLOCK_STATS_URL\""
                        echo $CURL_OUTPUT | jq -r '.data[]'
                fi

                if [ "$CURL_OUTPUT" == "" ]; then
                        echo "NO DATA FOUND"
                else
                        MEASUREMENT="pool_stats"
			TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},data_type=stats,api_token=${API_TOKEN},wallet_addr=${WALLET_ADDR}"
                        FIELDS_AND_DATE=`echo $CURL_OUTPUT | jq '.data[] | "difficulty=\(.difficulty),block_time=\"\(.block_time)\" \(.date)000000000"' `
                        echo $FIELDS_AND_DATE;
                        while read -r _LINE; do
                                LINE="${MEASUREMENT},${TAGS} ${_LINE}"
                                DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
                        done <<< "$FIELDS_AND_DATE"
                fi

	fi

	echo "done"
done

# Write to DB
if (( DEBUG == 1 )); then
	echo "$DATA_BINARY"
fi 
#curl -i -XPOST 'http://localhost:8086/write?db=rigdata' --data-binary "${DATA_BINARY}"

IFS=$SAVEIFS
rm ${BASE_DIR}/run/POOL_LOCK 

