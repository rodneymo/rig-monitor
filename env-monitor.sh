#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf

# epoch RUN_TIME
RUN_TIME=`date +%s%N`

if [ -f ${BASE_DIR}/run/ENV_LOCK ]; then
    	echo "env-monitor process still running! Exiting..."
	exit
else
	touch  ${BASE_DIR}/run/ENV_LOCK
fi

for ARGUMENT in "$@"; do
	if [ "$ARGUMENT" == "-trace" ]; then
		set -x
	elif [[ $ARGUMENT =~ ^-e[0-9]+ ]]; then
		DEBUG=1
		L_INDEX=${ARGUMENT:2}
		ENV_LIST=("${ENV_LIST[@]:$L_INDEX:1}")
	else
		echo "Argument unknonw: ${ARGUMENT}"
		rm ${BASE_DIR}/run/ENV_LOCK 
		exit
	fi
done

SAVEIFS=$IFS

# Call appropriate rig script
for ENV_LINE in "${ENV_LIST[@]}"
do
	IFS=$',' read RIG_ID PLUG_TYPE PLUG_IP MAX_POWER MAX_TEMP <<<${ENV_LINE}
	echo "collecting data from $RIG_NAME..."

	if (( DEBUG == 1 )); then
		echo "rig info in conf file: $ENV_LINE"
	fi
	if [[ "$PLUG_TYPE" == "TPLINK" ]]; then
		. ${BASE_DIR}/monitors/plug-${PLUG_TYPE,,}.sh
	fi
done

IFS=$SAVEIFS
rm ${BASE_DIR}/run/ENV_LOCK 

