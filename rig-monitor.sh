#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf

# epoch RUN_TIME
#RUN_TIME=`date +%s%N`

if [ -f ${BASE_DIR}/run/RIG_LOCK ]; then
    	echo "rig-monitor process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/RIG_LOCK
fi

for ARGUMENT in "$@"; do
        if [ "$ARGUMENT" == "-bt" ]; then
                set -x
		set -o functrace
        elif [ "$ARGUMENT" == "-d" ]; then
                DEBUG=1
	elif [[ $ARGUMENT =~ ^-r[0-9]+ ]]; then
		L_INDEX=${ARGUMENT:2}
		RIG_LIST=("${RIG_LIST[@]:$L_INDEX:1}")
	else
		echo "Argument unknonw: ${ARGUMENT}"
		rm ${BASE_DIR}/run/RIG_LOCK 
		exit
	fi
done

SAVEIFS=$IFS

# Call appropriate rig script
for RIG_LINE in "${RIG_LIST[@]}"
do
	IFS=$',' read RIG_ID MINER COIN_LABEL DCOIN_LABEL POOL_LABEL POOL_LABEL_DCOIN RIG_IP INSTALLED_GPUS TARGET_HR_ETH TARGET_HR_DCOIN PLUG_TYPE PLUG_IP MAX_POWER MAX_TEMP <<<${RIG_LINE}
	echo "collecting data from $RIG_ID..."

	if (( DEBUG == 1 )); then
		echo "rig info in conf file: $RIG_LINE"
	fi
	. ${BASE_DIR}/monitors/miner-${MINER,,}.sh
done

IFS=$SAVEIFS
rm ${BASE_DIR}/run/RIG_LOCK 


