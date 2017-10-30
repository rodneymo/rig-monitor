#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# epoch TIME
PORT=3333

TIME=`date +%s%N`

timeout 5 bash -c "exec 3<>/dev/tcp/${RIG_ID}/${PORT}" && CONNECTION_ERROR=0 || CONNECTION_ERROR=1
if (( CONNECTION_ERROR == 0 ));then
        exec 3<>/dev/tcp/${RIG_ID}/${PORT}
    	echo "{\"command\": \"summary+devs\"}" >&3
    	# load and capture sgminer's http status page
    	SGMINER_READOUT=`cat <&3 | jq -r '.'`

	if (( DEBUG == 1 )); then
		echo "$SGMINER_READOUT"
	fi

	FIELDS=`echo $SGMINER_READOUT | jq -r '.summary[0].SUMMARY[0] | "hr=\(."MHS 5s"),valid_shares=\(.Accepted),invalid_shares=\(.Rejected),stale_shares=\(.Stale),hw_errors=\(."Hardware Errors")"'`
	_MINING_TIME=`echo $SGMINER_READOUT | jq -r '.summary[0].SUMMARY[0].Elapsed'` 
	MINING_TIME=$(convertsecs $_MINING_TIME)
	NUM_GPUS=`echo $SGMINER_READOUT | jq -r '.devs[0].STATUS[0].Msg' | sed -e 's/ .*$//'`

	LINE="miner_system,rig_id=${RIG_ID},miner=sgminer,coin=${COIN_LABEL} installed_gpus=${INSTALLED_GPUS},active_gpus=${NUM_GPUS},$FIELDS,target_hr=${TARGET_HR},mining_time=\"${MINING_TIME}\" $TIME"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"

	GPU_TAG_AND_FIELDS=`echo $SGMINER_READOUT | jq -r '.devs[0].DEVS[] | "gpu_id=\(.GPU) gpu_online=\(.Status),gpu_hr=\(."MHS 5s"),gpu_valid_shares=\(.Accepted),gpu_invalid_shares=\(.Rejected),gpu_hw_erros=\(."Hardware Errors"),gpu_raw_intensity=\(.RawIntensity),gpu_temp=\(.Temperature),gpu_fan=\(."Fan Percent")"' | sed -e 's/gpu_online=Alive/gpu_online=1/g' `
	while read -r _GPU_TAG_AND_FIELDS;do
		LINE="miner_gpu,miner=sgminer,rig_id=${RIG_ID},$_GPU_TAG_AND_FIELDS $TIME"
		DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
	done <<< "$GPU_TAG_AND_FIELDS"
else
	LINE="miner_system,rig_id=${RIG_ID},miner=sgminer,coin=${COIN_LABEL} installed_gpus=${INSTALLED_GPUS},active_gpus=-1,target_hr=${TARGET_HR},hr=-1 $TIME"
	DATA_BINARY="${DATA_BINARY}"$'\n'"${LINE}"
fi

if (( DEBUG == 1 )); then
	echo "$LINE"
fi
