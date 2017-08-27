BEGIN {
	FS="[,]"
}
$1 ~ record_type {
	if ( $2 > last_record ) {
		print substr($0,5)
	 }
}



