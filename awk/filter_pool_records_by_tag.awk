#USED by pool-monitor.sh to fileter payout records
BEGIN {
	FS="[,]"
}
$2 ~ label && $3 ~ report {
	print $0
}



