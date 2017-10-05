#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf
. ${BASE_DIR}/lib/functions 

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

	############## Query coin price in BTC and QUOTE CURRENCY as defined in the conf file
	COIN_DATA_SQL="select * from coin_data where crypto='"${CRYPTO}"'"
	COIN_DATA=`curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" --data-urlencode \
		"q=${COIN_DATA_SQL}" | jq -r '.results[0].series[0].values[0] | "\(.[1]) \(.[2]) \(.[3]) \(.[5]) \(.[6]) \(.[7]) \(.[8]) \(.[9])" ' `
	if (( DEBUG == 1 )); then
		echo "SQL: ${COIN_DATA_SQL}"
		echo "HTTP QUERY: curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode \"db=rigdata\" --data-urlencode \"epoch=ns\" --data-urlencode \"q=${COIN_DATA_SQL}\""
		echo "OUTPUT: ${COIN_DATA}"
	fi

	IFS=$' ' read VOLUME_24H_QC BLOCK_REWARD BLOCK_TIME DIFFICULTY MARKET_CAP_QC PRICE_BTC PRICE_QC QUOTE_CURRENCY <<<${COIN_DATA}

	if (( DEBUG == 1 )); then
		echo -e "VOLUME_24H_QC:$VOLUME_24H_QC\nBLOCK_REWARD:$BLOCK_REWARD\nBLOCK_TIME:$BLOCK_TIME\nDIFFICULTY:$DIFFICULTY\nMARKET_CAP_QC:$MARKET_CAP_QC\nPRICE_BTC:$PRICE_BTC\nPRICE_QC:$PRICE_QC\nQUOTE_CURRENCY:$QUOTE_CURRENCY"
	fi
	
	############## Query workers in pool and calculate daily (24h) power consumption
	SQL="SELECT last(avg_hr) from workers_stats where label='"${LABEL}"'"
	LAST_RECORD=$(get_last_record "$SQL")

	# debug info
	if (( DEBUG == 1 )); then
		echo "SQL: ${SQL}"
		echo "HTTP QUERY: curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode \"db=rigdata\" --data-urlencode \"epoch=ns\" --data-urlencode \"q=${SQL}\""
                echo "LAST RECORD FROM SQL:${LAST_RECORD}"
		echo "calculating profitability from ${LAST_RECORD} until ${TIME} (now)"
	fi

	# SQL tags, fields
	#time avg_hr avg_hr_24h crypto current_hr invalid_shares label pool_type reported_hr stale_shares valid_shares worker_id
	WORKER_DATA_SQL="select last(avg_hr_24h),count(avg_hr_24h) from workers_stats where label='"${LABEL}"' and time >= $LAST_RECORD and time <=  $TIME group by time(24h), worker_id"
	WORKER_DATA=`curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" --data-urlencode q="$WORKER_DATA_SQL" | jq -r '.results[0].series[] | "\(.tags.worker_id) \(.values[]|map(.+0)|@csv)"' | sed -e 's/,/ /g' `

	# debug info
	if (( DEBUG == 1 )); then
		echo "SQL: ${WORKER_DATA_SQL}"
		echo "HTTP QUERY: curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode \"db=rigdata\" --data-urlencode \"epoch=ns\" --data-urlencode q=\"$WORKER_DATA_SQL\""
		echo "OUTPUT: ${WORKER_DATA}"
		echo ""
	fi

	while read  _WORKER_ID _DATE _AVG_HR_24H _COUNT;do 
		for RIG_LINE in "${RIG_LIST[@]}"; do
			IFS=$',' read RIG_ID MINER COIN_LABEL DCOIN_LABEL RIG_IP INSTALLED_GPUS TARGET_HR_ETH TARGET_HR_DCOIN PLUG_TYPE PLUG_IP MAX_POWER MAX_TEMP <<<${RIG_LINE}
			if [[ "$RIG_ID" == "$_WORKER_ID" ]]; then 
				WORKER_POWER_SQL="select mean(power_usage) from env_data where rig_id='"${RIG_ID}"' and time >= $LAST_RECORD and time <=  $TIME group by time(24h)"
				WORKER_POWER=`curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" --data-urlencode q="$WORKER_POWER_SQL" | jq -r '.results[0].series[0].values[] | "\(.[0]) \(.[1])"'| sed -e 's/null/0/g'  `
				# debug info
				if (( DEBUG == 1 )); then
					echo "SQL: ${WORKER_POWER_SQL}"
					echo "HTTP QUERY: curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode \"db=rigdata\" --data-urlencode \"epoch=ns\" --data-urlencode q=\"$WORKER_POWER_SQL\""
					echo "OUTPUT: ${WORKER_POWER}"
				fi
			fi
		done

	done <<< "$WORKER_DATA"

	continue
	##############  Aggregate pool revenue,cost, profitability
	SQL="SELECT last(revenue) from profitability where label='"${LABEL}"'"
	LAST_RECORD=$(get_last_record $SQL)

	# debug info
	if (( DEBUG == 1 )); then
		echo "SQL: ${SQL}"
		echo "HTTP QUERY: curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode \"db=rigdata\" --data-urlencode \"epoch=ns\" --data-urlencode \"q=${LAST_RECORD_SQL}\""
                echo "LAST RECORD FROM SQL:${LAST_RECORD}"
		echo "calculating profitability from ${LAST_RECORD} until ${TIME} (now)"
	fi

	if [[ "$POOL_TYPE" == "MPOS" ]]; then
		REVENUE_24H_SQL="select amount from pool_payments where time >= $LAST_RECORD and time <= $TIME and label='"${LABEL}"'"
		REVENUE_24H=`curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" \
			--data-urlencode "q=${REVENUE_24H_SQL}" | jq -r '.results[0].series[0].values[] | "\(.[0]) \(.[1])"' |  sed -e 's/null/0/g' `
	else
		REVENUE_24H_SQL="select sum(amount) from pool_payments where time >= $LAST_RECORD and time <= $TIME and label='"${LABEL}"' group by time(24h)"
		REVENUE_24H=`curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode "db=rigdata" --data-urlencode "epoch=ns" \
			--data-urlencode "q=${REVENUE_24H_SQL}" | jq -r '.results[0].series[0].values[] | "\(.[0]) \(.[1])"' | sed -e 's/null/0/g' ` 
	fi
	if (( DEBUG == 1 )); then
		echo "SQL: ${REVENUE_24H_SQL}"
		echo "HTTP QUERY: curl -sG 'http://localhost:8086/query?pretty=true' --data-urlencode \"db=rigdata\" --data-urlencode \"epoch=ns\" --data-urlencode q=\"$REVENUE_24H_SQL\""
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

