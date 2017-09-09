#USED by pool-monitor.sh
BEGIN {
	FS="[,]"
}
$2 ~ label && $3 ~ report {
	if ( $1 > last_record ) {
		print $0
	 }
}



