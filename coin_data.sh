#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf
. ${BASE_DIR}/lib/functions

# epoch RUN_TIME
RUN_TIME=`date +%s`

if [ -f ${BASE_DIR}/run/COIN_LOCK ]; then
    	echo "coinmarket process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/COIN_LOCK
fi

for ARGUMENT in "$@"; do
        if [ "$ARGUMENT" == "-bt" ]; then
                set -x
        elif [ "$ARGUMENT" == "-d" ]; then
                DEBUG=1
        else
                echo "Argument unknonw: ${ARGUMENT}"
		rm ${BASE_DIR}/run/COIN_LOCK 
		exit
        fi
done

SAVEIFS=$IFS


############# query crypto netwwork info from whattomine #############

WTM_URL="https://whattomine.com/coins.json"
WTM_OUTPUT=`curl -s -m 10 "${WTM_URL}" | jq -r '.'`
if (( DEBUG == 1 )); then
	echo "whattomine URL: ${WTM_URL}"
	echo "$WTM_OUTPUT"
fi

if [ "$WTM_OUTPUT" == "" ]; then
        echo "whattomine.com seems to be down"
fi

############# query coinmarketcap.com #############

CMC_URL="https://api.coinmarketcap.com/v1/ticker/"
if [ "$QUOTE_CURRENCY" != "USD" ]; then
	CMC_URL="${CMC_URL}?convert=${QUOTE_CURRENCY}"
fi

CMC_OUTPUT=`curl -s -m 10 "${CMC_URL}" | jq -r '.'`
if (( DEBUG == 1 )); then
	echo "coinmarketcap URL: ${CMC_URL}"
	echo "$CMC_OUTPUT"
fi

if [ "$CMC_OUTPUT" == "" ]; then
        echo "coinmarketcap seems to be down"
fi

############ parse and merge data ################
for POOL_LINE in "${POOL_LIST[@]}"
do
	IFS=$',' read POOL_TYPE CRYPTO LABEL BASE_API_URL API_TOKEN WALLET_ADDR <<<${POOL_LINE}

	if (( DEBUG == 1 )); then
		echo "Looking up network info for ${CRYPTO}/${QUOTE_CURRENCY}"
	fi

	MEASUREMENT="coin_data"
	TAGS="crypto_name=${CRYPTO},quote_currency=${QUOTE_CURRENCY}"
	WTM_FIELDS=`echo $WTM_OUTPUT | jq -r --arg crypto "$CRYPTO" '.coins | to_entries[] | select (.value.tag==$crypto) | "difficulty=\(.value.difficulty),block_reward=\(.value.block_reward),block_time=\(.value.block_time)"' | sed 's/null/0/g' `


	if [ "$QUOTE_CURRENCY" != "USD" ]; then
		PRICE="price_${QUOTE_CURRENCY,,}"
		VOLUME="24h_volume_${QUOTE_CURRENCY,,}"
		MARKET="market_cap_${QUOTE_CURRENCY,,}"
		FIELDS=`echo $CMC_OUTPUT | jq -r --arg crypto "$CRYPTO" --arg price $PRICE --arg volume $VOLUME --arg market $MARKET --arg currency $QUOTE_CURRENCY '.[] | select (.rank=="$crypto") | "\($price)=\(.[$price]),price_btc=\(.price_btc),\($volume)=\(.[$volume]),\($market)=\(.[$market])"' `

	else
		FIELDS=`echo $CMC_OUTPUT | jq -r --arg crypto "$CRYPTO" '.[] | select (.symbol==$crypto) | "price_usd=\(.price_usd),price_btc=\(.price_btc),24h_volume_usd=\(."24h_volume_usd"),market_cap_usd=\(.market_cap_usd)"'  `
		echo "$CRYPTO"
		echo "$FIELDS"

	fi
	LINE="${MEASUREMENT},${TAGS} ${FIELDS},${WTM_FIELDS}"
	LINE=`echo $LINE | sed -e 's/,$//g' `
	if (( DEBUG == 1 )); then
		echo "${LINE}"
	fi
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"

done

if (( DEBUG == 1 )); then
	echo "$DATA_BINARY"
fi 
curl -i -XPOST 'http://localhost:8086/write?db=rigdata' --data-binary "${DATA_BINARY}"

IFS=$SAVEIFS
rm ${BASE_DIR}/run/COIN_LOCK 

