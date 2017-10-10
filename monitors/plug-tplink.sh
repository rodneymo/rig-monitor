#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# read power usage from smart plug
POWER_USAGE=`${BASE_DIR}/lib/tplink-smartplug.py -t ${PLUG_IP} -j '{"emeter":{"get_realtime":{}}}' | grep Received | sed 's/.*power\":\(\w\+\).*/\1/'`

if (( DEBUG == 1 )); then
	echo $RIG_ID, $POWER_USAGE
fi

# parse miner output, prepare data for influxdb ingest and filter out null tags, fields
MEASUREMENT="env_data"
if [ -z "${POOL_LABEL_DCOIN}" ];then
        TAGS="plug_type=${PLUG_TYPE},rig_id=${RIG_ID}",label=${POOL_LABEL}
        FIELDS="power_usage="${POWER_USAGE}
        LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
        DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
else
        # power entry for COIN
        TAGS="plug_type=${PLUG_TYPE},rig_id=${RIG_ID}",label=${POOL_LABEL}
        _POWER_USAGE=`echo "print ${POWER_USAGE} * (1-${PWR_RATIO_DUAL_MINING})" | python`
        FIELDS="power_usage="${_POWER_USAGE}
        LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
        DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
        # power entry for DCOIN
        TAGS="plug_type=${PLUG_TYPE},rig_id=${RIG_ID}",label=${POOL_LABEL_DCOIN}
        _POWER_USAGE=`echo "print ${POWER_USAGE} * ${PWR_RATIO_DUAL_MINING}" | python`    
        FIELDS="power_usage="${_POWER_USAGE}
        LINE="${MEASUREMENT},${TAGS} ${FIELDS} ${RUN_TIME}"
        DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
fi

if (( DEBUG == 1 )); then
        echo "$DATA_BINARY"
fi

IFS=$SAVEIFS

