#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# epoch TIME
PORT=4028

TIME=`date +%s%N`

timeout 5 bash -c "exec 3<>/dev/tcp/${RIG_IP}/${PORT}" && CONNECTION_ERROR=0 || CONNECTION_ERROR=1
if (( CONNECTION_ERROR == 0 ));then
        exec 3<>/dev/tcp/${RIG_IP}/${PORT}
    	echo "{\"command\": \"summary+stats\"}" >&3
    	# load and capture sgminer's http status page
    	SGMINER_READOUT=`cat <&3 | sed 's/}{/},{/g' | jq -r '.'`

	if (( DEBUG == 1 )); then
		echo "$SGMINER_READOUT"
	fi

	FIELDS=`echo $SGMINER_READOUT | jq -r '.summary[0].SUMMARY[0] | "total_hr=\(."GHS 5s"),total_shares=\(.Accepted),rej_shares=\(.Rejected),stale_shares=\(.Stale),hw_errors=\(."Hardware Errors")"'`
	_MINING_TIME=`echo $SGMINER_READOUT | jq -r '.summary[0].SUMMARY[0].Elapsed'` 
	MINING_TIME=$(convertsecs $_MINING_TIME)
	ASC_NUM=`echo $SGMINER_READOUT | jq -r '.stats|.[]|.STATS|.[1]|.miner_count'`
	echo $ASC_NUM
	#NUM_GPUS=`echo $SGMINER_READOUT | jq -r '.devs[0].STATUS[0].Msg' | sed -e 's/ .*$//'`

	LINE="miner_system,rig_id=${RIG_ID},miner=antminer,coin=${COIN_LABEL} installed_gpus=${INSTALLED_GPUS},active_gpus=${ASC_NUM},$FIELDS,target_hr=${TARGET_HR},mining_time=\"${MINING_TIME}\" $TIME"
	if (( DEBUG == 1 )); then
	      echo "$LINE"
	fi

	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"

	for value in $(seq 1 ${ASC_NUM});do
		_GPU_TAG_AND_FIELDS=`echo $SGMINER_READOUT | jq -r '.stats|.[]|.STATS|.[1] | "gpu_hr=\(.chain_rate'${value}'),gpu_hw_errors=\(.chain_hw'${value}'),gpu_temp=\(.temp2_'${value}')"'` 
		#sed 's/null/0/g'``
		LINE="miner_gpu,miner=antminer,rig_id=${RIG_ID},gpu_id=${value} $_GPU_TAG_AND_FIELDS $TIME"
                if (( DEBUG == 1 )); then
                        echo "$LINE"
                fi
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
	done

else
	LINE="miner_system,rig_id=${RIG_ID},miner=antminer,coin=${COIN_LABEL} installed_gpus=${INSTALLED_GPUS},active_gpus=-1,target_hr=${TARGET_HR},total_hr=-1 $TIME"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
fi

if (( DEBUG == 1 )); then
	echo "$LINE"
fi
