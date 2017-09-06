BEGIN {
	FS="[,]"
}
/^bale/ {
	if ( $3 > last_record ) {
		print $0
	}
}

