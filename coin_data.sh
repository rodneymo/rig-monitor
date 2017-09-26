#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf
. ${BASE_DIR}/lib/functions

# epoch RUN_TIME
RUN_TIME=`date +%s`

if [ -f ${BASE_DIR}/run/COINMARKET_LOCK ]; then
    	echo "coinmarket process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/COINMARKET_LOCK
fi

for ARGUMENT in "$@"; do
        if [ "$ARGUMENT" == "-trace" ]; then
                set -x
        elif [[ $ARGUMENT =~ ^-c[0-9]+ ]]; then
                DEBUG=1
                L_INDEX=${ARGUMENT:2}
                COIN_LIST=("${COIN_LIST[@]:$L_INDEX:1}")
        else
                echo "Argument unknonw: ${ARGUMENT}"
		rm ${BASE_DIR}/run/COINMARKET_LOCK 
		exit
        fi
done

SAVEIFS=$IFS


############# query crypto netwwork info from whattomine #############

WHATTOMINE_URL="https://whattomine.com/coins.json"

WHATTOMINE_OUTPUT=`curl -s "${WHATTOMINE_URL}" | jq -r '.'`
if (( DEBUG == 1 )); then
	echo $WHATTOMINE_URL
fi

API_STATUS=`echo $WHATTOMINE_OUTPUT | jq -r '.'`

if [ "$API_STATUS" == "" ]; then
        echo "WHATTOMINE website seems to be down"
fi

############# query coinmarketcap.com #############
for COIN_LINE in "${COIN_LIST[@]}"
do
	IFS=$',' read BASE_CURRENCY QUOTE_CURRENCY <<<${COIN_LINE}
	if (( DEBUG == 1 )); then
		echo $BASE_CURRENCY $QUOTE_CURRENCY
	fi

	COIN_URL="https://api.coinmarketcap.com/v1/ticker/${BASE_CURRENCY}/"
	if [ "$QUOTE_CURRENCY" != "USD" ]; then
		COIN_URL="${COIN_URL}?convert=${QUOTE_CURRENCY}"
	fi

	if (( DEBUG == 1 )); then
		echo $COIN_URL
	fi

	CURL_OUTPUT=`curl -s "${COIN_URL}" | jq -r '.'`
	if (( DEBUG == 1 )); then
		echo $CURL_OUTPUT
	fi

        CURL_STATUS=`echo $CURL_OUTPUT | jq -r '.error?'`
	if (( DEBUG == 1 )); then
		echo $CURL_STATUS
	fi
        if [ "$CURL_STATUS" == "id not found" ]; then
                echo "$BASE_CURRENCY DOES NOT EXIST. PLEASE CHECK CONF FILE"
		continue
	fi

	MEASUREMENT="coinmarketcap"
	CRYPTO_SYMBOL=`echo $CURL_OUTPUT | jq -r '.[].symbol'` 
	TAGS="crypto_name=${BASE_CURRENCY},base_currency=${CRYPTO_SYMBOL},quote_currency=${QUOTE_CURRENCY}"
	if (( DEBUG == 1 )); then
		echo "Looking up network info for ${BASE_CURRENCY}(${CRYPTO_SYMBOL})"
	fi

	WHATTOMINE_FIELDS=`echo $WHATTOMINE_OUTPUT | jq -r --arg crypto $CRYPTO_SYMBOL '.coins | to_entries[] | select (.value.tag==$crypto) | "difficulty=\(.value.difficulty),block_reward=\(.value.block_reward),block_time=\(.value.block_time)"' | sed 's/null/0/g' `
	if [ "${WHATTOMINE_FIELDS}" != "" ]; then
		WHATTOMINE_FIELDS=",${WHATTOMINE_FIELDS}"
	fi
	if (( DEBUG == 1 )); then
		echo $WHATTOMINE_FIELDS
	fi

	if [ "$QUOTE_CURRENCY" != "USD" ]; then
		PRICE="price_${QUOTE_CURRENCY,,}"
		VOLUME="24h_volume_${QUOTE_CURRENCY,,}"
		MARKET="market_cap_${QUOTE_CURRENCY,,}"

		FIELDS=`echo $CURL_OUTPUT | jq -r --arg price $PRICE --arg volume $VOLUME --arg market $MARKET --arg currency $QUOTE_CURRENCY '.[] | "\($price)=\(.[$price]),price_btc=\(.price_btc),\($volume)=\(.[$volume]),\($market)=\(.[$market])"' `
	else
		FIELDS=`echo $CURL_OUTPUT | jq -r '.[] | "price_usd=\(.price_usd),price_btc=\(.price_btc),24h_volume_usd=\(."24h_volume_usd"),market_cap_usd=\(.market_cap_usd)"'  `

	fi
	LINE="${MEASUREMENT},${TAGS} ${FIELDS}${WHATTOMINE_FIELDS}"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"

done

if (( DEBUG == 1 )); then
	echo "$DATA_BINARY"
fi 
curl -i -XPOST 'http://localhost:8086/write?db=rigdata' --data-binary "${DATA_BINARY}"

IFS=$SAVEIFS
rm ${BASE_DIR}/run/COINMARKET_LOCK 

