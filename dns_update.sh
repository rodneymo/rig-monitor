#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $BASE_DIR

. ${BASE_DIR}/conf/rig-monitor.conf

rm ${LOG_DIR}/update?hostname=*
MYIP=`dig +short myip.opendns.com @resolver1.opendns.com`
wget "https://api.dynu.com/nic/update?hostname=${DYNU_HOST}&myip=${MYIP}&myipv6=no&username=${DYNU_USER}&password=${DYNU_PWD}" -a $LOG_DIR/dns_update.log
