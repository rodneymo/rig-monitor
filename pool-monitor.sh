#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf

# epoch RUN_TIME
#RUN_TIME=`date +%s`

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
#		MYSQL_VERBOSE=" -vvv --show-warnings " 
		L_INDEX=${ARGUMENT:2}
		POOL_LIST=("${POOL_LIST[@]:$L_INDEX:1}")
	else
		echo "Argument unknonw: ${ARGUMENT}"
		rm ${BASE_DIR}/run/POOL_LOCK 
		exit
	fi
done

SAVEIFS=$IFS

# Call appropriate pool script
for POOL_LINE in "${POOL_LIST[@]}"
do
	IFS=$',' read POOL_TYPE CRYPTO LABEL BASE_API_URL API_TOKEN WALLET_ADDR <<<${POOL_LINE}
	if (( DEBUG == 1 )); then
		echo "Pool info in conf file: $POOL_TYPE $CRYPTO $LABEL $BASE_API_URL $API_TOKEN $WALLET_ADDR"
	fi
	. ${BASE_DIR}/monitors/pool-${POOL_TYPE,,}.sh
done

IFS=$SAVEIFS
rm ${BASE_DIR}/run/POOL_LOCK 

