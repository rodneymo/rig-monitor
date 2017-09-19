#!/bin/bash

# Lazy programming to convert globals to locals, cleanup later
POOL="${POOL_TYPE}"
COIN="${CRYPTO,,}"
COIN_ADDR="${WALLET_ADDR}"
INFLUXDB_IP='localhost'

# Cleanup this later
for ARGUMENT in "$@"; do
        if [ "$ARGUMENT" == "-trace" ]; then
                set -x
        elif [[ $ARGUMENT =~ ^-p[0-9]+ ]]; then
                DEBUG=1
                #L_INDEX=${ARGUMENT:2}
                #POOL_LIST=("${POOL_LIST[@]:$L_INDEX:1}")
        else
                echo "Argument unknonw: ${ARGUMENT}"
                rm ${BASE_DIR}/run/POOL_LOCK
                exit
        fi
done


# Get general account and worker data
CURLOUT=`curl -s -m 10 "https://api.nanopool.org/v1/$COIN/user/$COIN_ADDR"`

if [ "$DEBUG" == 1 ]; then
	echo $CURLOUT
fi

if [ "$CURLOUT" == "" ]; then
	echo "CURL FAILED to connect to pool API"
else
	echo "CURL SUCCESS"
	IDB_WORKERS=`echo $CURLOUT | jq -r '.data | .workers | .[] | [.id,.hashrate,.lastShare,.rating] | @csv' \
			| tr -d '" ' \
			| awk -v POOL="$POOL" -v COIN="$COIN" -F "," '{print "pool_stats_workers,pool="POOL",coin="COIN",worker="$1" hashrate="$2",lastShare="$3",shares="$4}'`
	echo "$IDB_WORKERS"

	# WRITE Pool workers to DB
	curl -s -m 5 -XPOST "http://$INFLUXDB_IP:8086/write?db=rigdata" --data-binary "$IDB_WORKERS"

	IDB_ACCOUNT=`echo $CURLOUT | jq -r '.data | [.unconfirmed_balance,.balance,.hashrate] | @csv' \
			| tr -d '" ' \
			| awk -v POOL="$POOL" -v COIN="$COIN" -F "," '{print "pool_acct,pool="POOL",coin="COIN" unc_balance="$1",balance="$2",hashrate="$3}'` 
	echo "$IDB_ACCOUNT"

	# Write Pool Account data
	curl -s -m 5 -XPOST "http://$INFLUXDB_IP:8086/write?db=rigdata" --data-binary "$IDB_ACCOUNT"

fi

# Get payment history.
CURLOUT=`curl -s -m 10 "https://api.nanopool.org/v1/$COIN/payments/$COIN_ADDR"`

if [ "$DEBUG" == 1 ]; then
        echo $CURLOUT
fi

if [ "$CURLOUT" == "" ]; then
	echo "CURL FAILED to connect to pool API"
else
	echo "CURL SUCCESS"
	IDB_PAYMENTS=`echo $CURLOUT | jq -r '.data | .[] | [.date,.txHash,.amount,.confirmed] | @csv' \
			| tr -d '" ' \
			| awk -v POOL="$POOL" -v COIN="$COIN" -F "," '{print "pool_payments,pool="POOL",coin="COIN" txhash=\""$2"\",amount="$3",confirmed="$4" "$1}'`	
	echo "$IDB_PAYMENTS"
	
	# Write entire payment history, payments with same date will be ignored, this could be improved, API does not accept date ranges here?
	curl -s -m 5 -XPOST "http://$INFLUXDB_IP:8086/write?db=rigdata&precision=s" --data-binary "$IDB_PAYMENTS"

fi


