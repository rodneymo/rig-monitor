#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf

#Current time
TIME=`date +%s%N`



if [ -f ${BASE_DIR}/run/PROFIT_LOCK ]; then
    	echo "profit calculator process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/PROFIT_LOCK
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
		rm ${BASE_DIR}/run/PROFIT_LOCK 
		exit
	fi
done

SAVEIFS=$IFS

for POOL_LINE in "${POOL_LIST[@]}"
do
	IFS=$',' read POOL_TYPE CRYPTO LABEL BASE_API_URL API_TOKEN WALLET_ADDR <<<${POOL_LINE}
	if (( DEBUG == 1 )); then
		echo "Pool info in conf file: $POOL_TYPE $CRYPTO $LABEL"
	fi

	# Query pool payments
	# Query coin_data
	# Calculate revenue, costs and profit for all periods (24h,7d,30d)
	LAST_RECORD_SQL="SELECT last(revenue) from profitability where label='"${LABEL}"'"
	if (( DEBUG == 1 )); then
		echo "SQL: ${LAST_RECORD_SQL}"
	fi
	LAST_RECORD=`curl -G 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" --data-urlencode "q=${LAST_RECORD_SQL}" \
		| jq -r '.results[0].series[0].values[0][0]' | awk '/^null/ { print 0 }; /[0-9]+/ {print substr($1,1,10) };' `
	if (( LAST_RECORD == 0 )); then
		# Get epoch from 1 month ago and round it to 12:00am
		_TIME=`date -d "1 month ago" +%s`
		LAST_RECORD=$(( ${_TIME} - (${_TIME} % (24 * 60 * 60)) ))000000000
	fi
	if (( DEBUG == 1 )); then
		echo "calculating profitability from ${LAST_RECORD} until ${TIME} (now)"
	fi
	if [[ "$POOL_TYPE" == "MPOS" ]]; then
		PAYMENT_RECORDS_SQL="select amount from pool_payments where time >= $LAST_RECORD and time <= $TIME and label='"${LABEL}"'"
		PAYMENT_RECORDS=`curl -G 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" --data-urlencode "q=${PAYMENT_RECORDS_SQL}" \
			| jq -r '.results[0].series[0].values[] | "date=\(.[0]),revenue=\(.[1])"' `
	else
		PAYMENT_RECORDS_SQL="select sum(amount) from pool_payments where time >= $LAST_RECORD and time <= $TIME and label='"${LABEL}"' group by time(24h)"
		PAYMENT_RECORDS=`curl -G 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" --data-urlencode "q=${PAYMENT_RECORDS_SQL}" \
			| jq -r '.results[0].series[0].values[] | "revenue=\(.[1]) \(.[0])"' `
	fi
	MEASUREMENT="revenue"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	while read -r FIELDS_AND_TIME;do 
		LINE="${MEASUREMENT},${TAGS} ${FIELDS_AND_TIME}"
		if (( DEBUG == 1 )); then
			echo "$LINE"
		fi 
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
	done <<< "$PAYMENT_RECORDS"

done

# Write to DB
#curl -i -XPOST 'http://localhost:8086/write?db=rigdata' --data-binary "${DATA_BINARY}"

IFS=$SAVEIFS
rm ${BASE_DIR}/run/PROFIT_LOCK 

