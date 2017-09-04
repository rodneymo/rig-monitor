BEGIN {
	FS = "[ ,:()]"
	GPU_INDEX=0
}

# IGNORE LINES WITH SHARE FOUND MESSAGE
/SHARE FOUND/ {next}
/Share accepted/ {next}
# IGNORE LINES WITH INCORRECT SHARES WARNING
/ got incorrect share/ {next}

# READ NUMBER of GPUs
# GPU #0: Ellesmere, 8192 MB available, 36 compute units
/^GPU #/ { 
	GPU_INDEX++
} 

# READ TOTAL HASHRATE and SHARE INFO  E.G.
# ETH - Total Speed: 147.184 Mh/s, Total Shares: 2997(629+572+660+582+586), Rejected: 0, Time: 29:53
/^ETH - Total Speed: / { 
	#print $6,$12,$13,$18,$22,$23  
	current_hashrate = $6
	total_shares = $12
	split($13,gpu_shares,"+")
	for ( i = 0; i < GPU_INDEX; i++ ) {
		gpu[i,"SHARES"]=gpu_shares[i+1]
	}
	rejected_shares = $18
	mining_time = $22  $23 "00" 
}	

# READ GPU HASHRATE E.G.
# ETH: GPU0 27.688 Mh/s, GPU1 27.789 Mh/s, GPU2 26.442 Mh/s, GPU3 27.245 Mh/s, GPU4 27.072 Mh/s, GPU5 27.053 Mh/s
/^ETH:/ {
        #print $4,$8,$12,$16,$20,$24
	gpu_field=4
	while ( gpu_field < NF ) {
		_index = gpu_field/4 - 1
		gpu[_index,"HASHRATE"]=$gpu_field
		gpu_field+=4	
	}
}

# READ INCORRECT SHARES E.G.
# Incorrect ETH shares: GPU1 23, GPU2 34
/^Incorrect ETH shares:/ { 
	gpu_field = 5 
	while ( gpu_field < NF ) {
		_index = substr($gpu_field,4,1)
		gpu[_index,"BAD_SHARES"] = $(gpu_field+1)
		gpu_field+=3
	}
}

# READ ! MIN AVERAGE HASRATE E.G.
#  1 minute average ETH total speed: 163.095 Mh/s
/^ 1 minute average / { average_hashrate = $9 }

# READ EPOCH AND DAG
# Current ETH share target: 0x00000000ffb34c02 (diff: 4300MH), epoch 27(1.21GB)
/^Current ETH share target/ { 
	dag = $14 
	dag_size = $15
	}

# READ FAN SPEED and TEMP FROM GPUS E.G. 
#GPU0 t=68C fan=79%, GPU1 t=68C fan=61%, GPU2 t=68C fan=65%, GPU3 t=67C fan=66%, GPU4 t=68C fan=38%, GPU5 t=66C fan=38%
/^GPU0 t/ {
        gpu_field = 1
        while ( gpu_field < NF ) {
                _index = substr($gpu_field,4,1)
		_temp = substr($(gpu_field+1),3,2)
		_fan = substr($(gpu_field+2),5,(index($(gpu_field+2),"%")-5))
                gpu[_index,"TEMP"] = _temp
                gpu[_index,"FAN"] = _fan
                gpu_field+=4
        }
}

END {
	print "RIG," time "," rig_name "," GPU_INDEX "," average_hashrate "," total_shares "," rejected_shares "," power_usage "," mining_time

	for ( gpu_id = 0; gpu_id < GPU_INDEX; gpu_id++ ) {
		print "GPU," time "," rig_name "/" gpu_id "," gpu[gpu_id,"HASHRATE"] "," gpu[gpu_id,"SHARES"] "," gpu[gpu_id,"BAD_SHARES"] "," gpu[gpu_id,"TEMP"] "," gpu[gpu_id,"FAN"]
	}

#	print "SYSTEM NAME: " rig_name
#	print "\tAVERAGE HASHRATE: " average_hashrate
#	print "\tTOTAL SHARES: " total_shares
#	print "\tREJECTED SHARES: " rejected_shares
#	print "\tMINING TIME: " mining_time
#	print "\tDAG INFO: " dag ", " dag_size

#	for ( i = 0; i < GPU_INDEX; i++ ) {
#		print "GPU#" i
#		print "\tSHARES: " gpu[i,"SHARES"]
#		print "\tINCORRECT_SHARES: " gpu[i,"BAD_SHARES"]
#		print "\tHASHRATE: " gpu[i,"HASHRATE"]
#		print "\tTEMP.(C): " gpu[i,"TEMP"]
#		print "\tFAN SPEED: " gpu[i,"FAN"]
#	}
}

