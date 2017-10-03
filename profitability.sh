#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf

#Current time
TIME=`date +%s%N`

unset $DATA_BINARY

if [ -f ${BASE_DIR}/run/PROFIT_LOCK ]; then
    	echo "profit calculator process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/PROFIT_LOCK
fi

for ARGUMENT in "$@"; do
	if [ "$ARGUMENT" == "-bt" ]; then
		set -x
	elif [ "$ARGUMENT" == "-d" ]; then
		DEBUG=1
	elif [[ $ARGUMENT =~ ^-p[0-9]+ ]]; then
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
		echo ""
		echo "Pool info in conf file: $POOL_TYPE $CRYPTO $LABEL"
	fi

	PRICE="price_${QUOTE_CURRENCY,,}"
	VOLUME="24h_volume_${QUOTE_CURRENCY,,}"
	MARKET="market_cap_${QUOTE_CURRENCY,,}"

	# Query coin price in BTC and QUOTE CURRENCY as defined in the conf file
	COIN_DATA_SQL="select * from coin_data where crypto='"${CRYPTO}"'"
	COIN_DATA=`curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" --data-urlencode \
		"q=${COIN_DATA_SQL}" | jq -r '.results[0].series[0].values[0] | "\(.[1]) \(.[2]) \(.[3]) \(.[5]) \(.[6]) \(.[7]) \(.[8]) \(.[9])" ' `
	if (( DEBUG == 1 )); then
		echo "SQL: ${COIN_DATA_SQL}"
		echo "OUTPUT: ${COIN_DATA}"
	fi

	IFS=$' ' read VOLUME_24H_QC BLOCK_REWARD BLOCK_TIME DIFFICULTY MARKET_CAP_QC PRICE_BTC PRICE_QC QUOTE_CURRENCY <<<${COIN_DATA}

	if (( DEBUG == 1 )); then
		echo -e "VOLUME_24H_QC:$VOLUME_24H_QC\nBLOCK_REWARD:$BLOCK_REWARD\nBLOCK_TIME:$BLOCK_TIME\nDIFFICULTY:$DIFFICULTY\nMARKET_CAP_QC:$MARKET_CAP_QC\nPRICE_BTC:$PRICE_BTC\nPRICE_QC:$PRICE_QC\nQUOTE_CURRENCY:$QUOTE_CURRENCY"
	fi
	
	# Aggregate pool payments in 24h periods
	LAST_RECORD_SQL="SELECT last(revenue) from profitability where label='"${LABEL}"'"
	if (( DEBUG == 1 )); then
		echo "SQL: ${LAST_RECORD_SQL}"
	fi
	LAST_RECORD=`curl -G 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" --data-urlencode \
		"q=${LAST_RECORD_SQL}" | jq -r '.results[0].series[0].values[0][0]' | awk '/^null/ { print 0 }; /[0-9]+/ {print substr($1,1,10) };' `
	if (( LAST_RECORD == 0 )); then
		# Get epoch from 1 month ago and round it to 12:00am
		_TIME=`date -d "1 month ago" +%s`
		LAST_RECORD=$(( ${_TIME} - (${_TIME} % (24 * 60 * 60)) ))000000000
	fi
	if (( DEBUG == 1 )); then
		echo "calculating profitability from ${LAST_RECORD} until ${TIME} (now)"
	fi
	if [[ "$POOL_TYPE" == "MPOS" ]]; then
		REVENUE_24H_SQL="select amount from pool_payments where time >= $LAST_RECORD and time <= $TIME and label='"${LABEL}"'"
		REVENUE_24H=`curl -G 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" \
			--data-urlencode "q=${REVENUE_24H_SQL}" | jq -r '.results[0].series[0].values[] | "\(.[0]) \(.[1])"' |  sed -e 's/null/0/g' `
	else
		REVENUE_24H_SQL="select sum(amount) from pool_payments where time >= $LAST_RECORD and time <= $TIME and label='"${LABEL}"' group by time(24h)"
		REVENUE_24H=`curl -G 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" \
			--data-urlencode "q=${REVENUE_24H_SQL}" | jq -r '.results[0].series[0].values[] | "\(.[0]) \(.[1])"' | sed -e 's/null/0/g' ` 
	fi
	if (( DEBUG == 1 )); then
		echo "SQL: ${REVENUE_24H_SQL}"
		echo "OUTPUT (DATE REVENUE): ${REVENUE_24H}"
	fi
	#VOLUME_24H_QC BLOCK_REWARD BLOCK_TIME DIFFICULTY MARKET_CAP_QC PRICE_BTC PRICE_QC QUOTE_CURRENCY
	MEASUREMENT="pool_profitability"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	while read  _DATE _REVENUE;do 
		if [[ "$POOL_TYPE" == "ETHERMINE" ]]; then
			_REVENUE=`echo "print ${_REVENUE}/1E18"|python`
		fi
		REVENUE_BTC=`echo "print ${_REVENUE}*${PRICE_BTC}"|python`  
		REVENUE_QC=`echo "print ${_REVENUE}*${PRICE_QC}"|python`  
		LINE="${MEASUREMENT},${TAGS} ${_REVENUE},${REVENUE_BTC},${REVENUE_QC} ${_DATE}"
		if (( DEBUG == 1 )); then
			echo "$LINE"
		fi 
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
	done <<< "$REVENUE_24H"

done

# Write to DB
#curl -i -XPOST 'http://localhost:8086/write?db=rigdata' --data-binary "${DATA_BINARY}"

IFS=$SAVEIFS
rm ${BASE_DIR}/run/PROFIT_LOCK 

