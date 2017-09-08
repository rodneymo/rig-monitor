#!/bin/bash
#Scan IP network for TP LINK plugs and print alias, IP

NETWORK="192.168.1.0"
START_IP=0
END_IP=80
PORT=9999

S_NETWORK=${NETWORK%.*}
COUNTER=$START_IP

while [  $COUNTER -lt $END_IP ]; do

	IP=${S_NETWORK}.${COUNTER}

	STATUS=`/bin/nc -v -z -w1 $IP $PORT 2>&1 | grep "succeeded" | wc -l`
	if [ $STATUS == "1" ]; then
		PLUG_NAME=`/usr/bin/python tplink-smartplug.py -t $IP -c info | grep Received | sed 's/.*alias\":\"\(\w\+\)\".*/\1/'`
		echo Plug $PLUG_NAME is online on $IP
	else
		sleep 0
		#echo "$IP is down"
	fi

        let COUNTER=COUNTER+1 
done
