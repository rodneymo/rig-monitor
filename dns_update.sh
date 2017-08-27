#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR='.'

. ${BASE_DIR}/conf/rig-monitor.conf

rm ${LOG_DIR}/update?hostname=*
MYIP=`dig +short myip.opendns.com @resolver1.opendns.com`
wget "https://api.dynu.com/nic/update?hostname=<hostname>&myip=${MYIP}&myipv6=no&username=<user>&password=<password>"
