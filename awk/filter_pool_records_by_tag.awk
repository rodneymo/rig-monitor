#USED by pool-monitor.sh
BEGIN {
	FS="[,]"
}
$1 ~ label && $2 ~ report {
	if ( $3 > last_record ) {
		print $0
	 }
}



