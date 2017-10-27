#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf
. ${BASE_DIR}/lib/functions 

unset DATA_BINARY

#Current time
TIME=`date +%s%N`
TIME_1DAY_AGO=`date --date="-1 day" +%s%N`

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
	elif [ "$ARGUMENT" == "-nw" ]; then
		NO_WRITE=1
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
	COIN_DATA=`curl -sG 'http://'${INFLUX_HOST}':8086/query?pretty=true' --data-urlencode "db=${INFLUX_DB}" --data-urlencode "epoch=ns" --data-urlencode \
		"q=${COIN_DATA_SQL}" | jq -r '.results[0].series[0].values[0] | "\(.[1]) \(.[2]) \(.[3]) \(.[5]) \(.[6]) \(.[7]) \(.[8]) \(.[9])" ' `
	IFS=$' ' read VOLUME_24H_QC BLOCK_REWARD BLOCK_TIME DIFFICULTY MARKET_CAP_QC PRICE_BTC PRICE_QC QUOTE_CURRENCY <<<${COIN_DATA}
	if (( DEBUG == 1 )); then
		echo "SQL: ${COIN_DATA_SQL}"
		echo "HTTP QUERY: curl -sG 'http://'${INFLUX_HOST}':8086/query?pretty=true' --data-urlencode \"db=${INFLUX_DB}\" --data-urlencode \"epoch=ns\" --data-urlencode \"q=${COIN_DATA_SQL}\""
		echo "OUTPUT: ${COIN_DATA}"
		echo -e "VOLUME_24H_QC:$VOLUME_24H_QC\nBLOCK_REWARD:$BLOCK_REWARD\nBLOCK_TIME:$BLOCK_TIME\nDIFFICULTY:$DIFFICULTY\nMARKET_CAP_QC:$MARKET_CAP_QC\nPRICE_BTC:$PRICE_BTC\nPRICE_QC:$PRICE_QC\nQUOTE_CURRENCY:$QUOTE_CURRENCY"
	fi
	if [[ "$PRICE_QC"  == "null" ]]; then
		echo "An error as occured. Coin and market informtion are not available in DB!"
		rm ${BASE_DIR}/run/PROFIT_LOCK 
		exit
	fi
	
	##############  Calculate pool revenue per 24h period
	SQL="SELECT last(revenue_24h) from pool_profitability where label='"${LABEL}"'"
	LAST_RECORD=$(get_last_record "$SQL")
	# debug info
	if (( DEBUG == 1 )); then
		echo "SQL: ${SQL}"
		echo "HTTP QUERY: curl -sG 'http://'${INFLUX_HOST}':8086/query?pretty=true' --data-urlencode \"db=${INFLUX_DB}\" --data-urlencode \"epoch=ns\" --data-urlencode \"q=${SQL}\""
                echo "LAST RECORD FROM SQL:${LAST_RECORD}"
		echo "calculating profitability from ${LAST_RECORD} until ${TIME} (now)"
	fi
	### Query revenue per pool per 24h period
	if [[ "$POOL_TYPE" == "MPOS" ]]; then
		REVENUE_24H_SQL="select amount from pool_payments where time >= $LAST_RECORD and time <= $TIME and label='"${LABEL}"'"
		REVENUE_24H=`curl -sG 'http://'${INFLUX_HOST}':8086/query?pretty=true' --data-urlencode "db=${INFLUX_DB}" --data-urlencode "epoch=ns" \
			--data-urlencode "q=${REVENUE_24H_SQL}" | jq -r '.results[0].series[0].values[]? | "\(.[0]) \(.[1])"' |  sed -e 's/null/0/g' `
	else
		REVENUE_24H_SQL="select sum(amount) from pool_payments where time >= $LAST_RECORD and time <= $TIME and label='"${LABEL}"' group by time(24h)"
		REVENUE_24H=`curl -sG 'http://'${INFLUX_HOST}':8086/query?pretty=true' --data-urlencode "db=${INFLUX_DB}" --data-urlencode "epoch=ns" \
			--data-urlencode "q=${REVENUE_24H_SQL}" | jq -r '.results[0].series[0].values[]? | "\(.[0]) \(.[1])"' | sed -e 's/null/0/g' ` 
	fi
	if (( DEBUG == 1 )); then
		echo "SQL: ${REVENUE_24H_SQL}"
		echo "HTTP QUERY: curl -sG 'http://'${INFLUX_HOST}':8086/query?pretty=true' --data-urlencode \"db=${INFLUX_DB}\" --data-urlencode \"epoch=ns\" --data-urlencode q=\"$REVENUE_24H_SQL\""
		echo "OUTPUT (DATE REVENUE): ${REVENUE_24H}"
	fi

	### Query power consumption per 24h for all rigs using POOL (kWh based on minute env_data.sh measurements: Power usage:  sum(power_usage)/1400 * 24)
	SQL="select sum(power_usage)/1440*24 from env_data where time >= $LAST_RECORD and time <= $TIME and label='"${LABEL}"' group by time(24h)"
        POWER_USAGE=`curl -sG 'http://'${INFLUX_HOST}':8086/query?pretty=true' --data-urlencode "db=${INFLUX_DB}" --data-urlencode "epoch=ns" \
                        --data-urlencode "q=${SQL}" | jq -r '.results[0].series[0].values[]? | "\(.[0]) \(.[1])"' |  sed -e 's/null/0/g' `
	if (( DEBUG == 1 )); then
		echo "SQL: ${SQL}"
		echo "HTTP QUERY: curl -sG 'http://'${INFLUX_HOST}':8086/query?pretty=true' --data-urlencode \"db=${INFLUX_DB}\" --data-urlencode \"epoch=ns\" --data-urlencode \"q=${SQL}\""
	fi
	# if power usage query was not zero then store results in array
	if [ ! -z "$POWER_USAGE" ];then
		declare -A POWER_COSTS_24H
		while read _DATE _POWER_USAGE;do 
			POWER_COSTS_24H[$_DATE]=`awk "BEGIN {print $_POWER_USAGE/1000 * $PWR_COSTS}"`
			if (( DEBUG == 1 )); then
				echo "DATE:${_DATE}, POWER USAGE:${_POWER_USAGE}, POWER COSTS:${POWER_COSTS_24H[$_DATE]}"
			fi
		done <<< "$POWER_USAGE"
	fi

	# Collate revenue and power costs into influx DB entries  
	MEASUREMENT="pool_profitability"
	TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL}"
	while read  _DATE _REVENUE;do 
		REVENUE_BTC=`awk "BEGIN {print $_REVENUE * $PRICE_BTC}"`  
		REVENUE_QC=`awk "BEGIN {print $_REVENUE * $PRICE_QC}"`  
		# Default value added to power_costs_24h in case no rigs are marked as using current pool and thus POWER_USAGE would be empty
		LINE="${MEASUREMENT},${TAGS} revenue_24h=${_REVENUE},revenue_btc_24h=${REVENUE_BTC},revenue_qc_24h=${REVENUE_QC},power_costs_24h=${POWER_COSTS_24H[${_DATE}]:-0} ${_DATE}"
		if (( DEBUG == 1 )); then
			echo "$LINE"
		fi 
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
	done <<< "$REVENUE_24H"


	######## Query list of workers (per pool) and calculate future worker profitability based on current hashrate and power consumption
	### Claculate power usage during the last 24h
	SQL="select mean(power_usage) from env_data where time >= $TIME_1DAY_AGO and time <= $TIME and label='"${LABEL}"' group by rig_id"
        POWER_USAGE=`curl -sG 'http://'${INFLUX_HOST}':8086/query?pretty=true' --data-urlencode "db=${INFLUX_DB}" --data-urlencode "epoch=ns" \
                        --data-urlencode "q=${SQL}" | jq -r '.results[0].series[]? | "\(.tags.rig_id) \(.values[0][1])"' `
	if (( DEBUG == 1 )); then
		echo "SQL: ${SQL}"
		echo "HTTP QUERY: curl -sG 'http://${INFLUX_HOST}:8086/query?pretty=true' --data-urlencode \"db=${INFLUX_DB}\" --data-urlencode \"epoch=ns\" --data-urlencode \"q=${SQL}\""
		echo "$POWER_USAGE"
	fi
	# if power usage query was not zero then store results in array
	if [ ! -z "$POWER_USAGE" ];then
		declare -A F_POWER_COSTS_24H
		while read _RIG_ID _POWER_USAGE;do 
			F_POWER_COSTS_24H[$_RIG_ID]=`awk "BEGIN {print $_POWER_USAGE/1000*24 * $PWR_COSTS}"`
			if (( DEBUG == 1 )); then
				echo "RIG_ID:${_RIG_ID}, POWER USAGE:${_POWER_USAGE}, POWER COSTS:${F_POWER_COSTS_24H[$_RIG_ID]}"
			fi
		done <<< "$POWER_USAGE"
	fi
	### Estimate future revenue per rig based on block reward, block mining time and network difficulty
	if [[ "$POOL_TYPE" == "MPOS" ]]; then
		SQL="select mean(current_hr) from worker_stats where time >= $TIME_1DAY_AGO and label='"${LABEL}"' group by rig_id"
	elif [[ "$POOL_TYPE" == "CRYPTONOTE" ]]; then
		SQL="select mean(hr) from worker_stats where time >= $TIME_1DAY_AGO and label='"${LABEL}"' group by rig_id"
	else
		SQL="select mean(avg_hr_24h) from worker_stats where time >= $TIME_1DAY_AGO and label='"${LABEL}"' group by rig_id"
	fi
        RIG_HR_LAST_24H=`curl -sG 'http://'${INFLUX_HOST}':8086/query?pretty=true' --data-urlencode "db=${INFLUX_DB}" --data-urlencode "epoch=ns" \
        	--data-urlencode "q=${SQL}" | jq -r '.results[0].series[]? | "\(.tags.rig_id) \(.values[0][0]) \(.values[0][1])"' `
	if (( DEBUG == 1 )); then
		echo "SQL: ${SQL}"
		echo "HTTP QUERY: curl -sG 'http://'${INFLUX_HOST}':8086/query?pretty=true' --data-urlencode \"db=${INFLUX_DB}\" --data-urlencode \"epoch=ns\" --data-urlencode \"q=${SQL}\" "
		echo "$RIG_HR_LAST_24H"
	fi
	while read _RIG_ID _TIME _HR;do
		if [[ -z $_HR ]]; then
			_HR=0
		fi
		EST_EARNINGS_DAY=`awk "BEGIN {print ($_HR/($DIFFICULTY/$BLOCK_TIME))*((60/$BLOCK_TIME)*$BLOCK_REWARD)*(60*24)*($PRICE_QC)}"`
		EST_POWER_COSTS_DAY=${F_POWER_COSTS_24H[${_RIG_ID}]}
		EST_PROFIT_DAY=`awk "BEGIN {print ($EST_EARNINGS_DAY-$EST_POWER_COSTS_DAY)}"`

		MEASUREMENT="future_profitability"
		TAGS="pool_type=${POOL_TYPE},crypto=${CRYPTO},label=${LABEL},rig_id=${_RIG_ID}"
		LINE="${MEASUREMENT},${TAGS} est_revenue_qc_24h=${EST_EARNINGS_DAY},est_power_costs_24h=${EST_POWER_COSTS_DAY},est_profit_24h=${EST_PROFIT_DAY} ${TIME}"
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
		if (( DEBUG == 1 )); then
			echo "EARNINGS PER DAY CALC: ($_HR/($DIFFICULTY/$BLOCK_TIME))*((60/$BLOCK_TIME)*$BLOCK_REWARD)*(60*24)*($PRICE_QC)"
			echo "$LINE"
		fi

	done  <<<"${RIG_HR_LAST_24H}"

done

# Write to DB
echo "$DATA_BINARY" > tmp/profitability_binary_data.tmp
if (( NO_WRITE == 1 ));then
	echo "NO WRITE enabled. Skipping influxDB http write"
else
	curl -s -i -XPOST 'http://'${INFLUX_HOST}':8086/write?db='${INFLUX_DB} --data-binary @tmp/profitability_binary_data.tmp
fi

IFS=$SAVEIFS
rm ${BASE_DIR}/run/PROFIT_LOCK 

