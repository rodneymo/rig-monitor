# used by coinmarket.sh
BEGIN {
	FS="[,]"
}
/^[0-9]+/ {
	if ( $1 > last_record ) {
		print $0
	}
}


