BEGIN {
	FS = "[ ,:]"
	GPU_INDEX=0
	TRACE=0
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

# READ ETH TOTAL HASHRATE and SHARE INFO  E.G.
#ETH - Total Speed: 160.966 Mh/s, Total Shares: 13015(2219+2204+2130+2167+2186+2226), Rejected: 0, Time: 100:02
/^ETH - Total Speed: / { 
	#print $6,$12,$16,$20,$21  
	current_hashrate_eth=$6
	total_shares_eth=$12
	_gpu_shares_eth=$12
	sub(/\([0-9+]+\)/,"",total_shares_eth)
	gsub(/^[0-9]+\(|\)/,"",_gpu_shares_eth)
	split(_gpu_shares_eth,gpu_shares_eth,"+")
	for ( i = 0; i < GPU_INDEX; i++ ) {
		gpu[i,"SHARES_ETH"]=gpu_shares_eth[i+1]
	}
	rejected_shares_eth = $16
	mining_time = $20  $21 "00" 
}	
# READ DCR/SC/LBC/PASC TOTAL HASHRATE and SHARE INFO  E.G.
#  SC - Total Speed: 43.678 Mh/s, Total Shares: 0, Rejected: 0 
/^  (DCR|SC|LBC|PASC) - Total Speed: / { 
	#print $8,$14,$18
	current_hashrate_dcoin = $8
	total_shares_dcoin = $14
	rejected_shares_dcoin = $18
}	

# READ ETH GPU HASHRATE E.G.
# ETH: GPU0 27.688 Mh/s, GPU1 27.789 Mh/s, GPU2 26.442 Mh/s, GPU3 27.245 Mh/s, GPU4 27.072 Mh/s, GPU5 27.053 Mh/s
/^ETH:/ {
        #print $4,$8,$12,$16,$20,$24
	gpu_field=4
	while ( gpu_field < NF ) {
		_index = gpu_field/4 - 1
		gpu[_index,"HASHRATE_ETH"]=$gpu_field
		gpu_field+=4	
	}
}

# READ DCR/SC/LBC/PASC GPU HASHRATE E.G.
#   SC: GPU0 43.678 Mh/s 
/^  (DCR|SC|LBC|PASC):/ {
        #print $5,$9,$13,$17,$21,$25
	gpu_field=6
	while ( gpu_field < NF ) {
		_index = gpu_field/6 - 1
		gpu[_index,"HASHRATE_DCOIN"]=$gpu_field
		gpu_field+=4	
	}
}

# READ INCORRECT SHARES E.G.
# Incorrect ETH shares: GPU1 23, GPU2 34
/^Incorrect ETH shares:/ { 
	gpu_field = 5 
	while ( gpu_field < NF ) {
		_index = substr($gpu_field,4,1)
		gpu[_index,"INC_SHARES_ETH"] = $(gpu_field+1)
		gpu_field+=3
	}
}

# READ ! MIN AVERAGE HASRATE E.G.
#  1 minute average ETH total speed: 163.095 Mh/s
/^ 1 minute average / { average_hashrate_eth = $9 }

# READ EPOCH AND DAG
# Current ETH share target: 0x00000000ffb34c02 (diff: 4300MH), epoch 27(1.21GB)
# Current ETH share target: 0x0000000112e0be82 (diff: 4000MH), epoch 141(2.10GB) Current SC share target: 0x0000000007547ff5 (diff: 150GH) 
/^Current ETH share target/ { 
        dag=$12
        dag_size=$12
        sub(/\([0-9A-Z\.]+\)/,"",dag)
        gsub(/^[0-9]+\(|\)/,"",dag_size)
	#print dag
	#print dag_size
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
        print "RIG," time "," rig_name "," GPU_INDEX "," current_hashrate_eth ","average_hashrate_eth "," total_shares_eth "," rejected_shares_eth "," current_hashrate_dcoin ","average_hashrate_dcoin ","  total_shares_dcoin "," rejected_shares_dcoin "," power_usage "," mining_time

        for ( gpu_id = 0; gpu_id < GPU_INDEX; gpu_id++ ) {
                print "GPU," time "," rig_name "/" gpu_id "," gpu[gpu_id,"HASHRATE_ETH"] "," gpu[gpu_id,"SHARES_ETH"] "," gpu[gpu_id,"INC_SHARES_ETH"] "," gpu[gpu_id,"HASHRATE_DCOIN"] "," gpu[gpu_id,"SHARES_DCOIN"] ","  gpu[gpu_id,"INC_SHARES_DCOIN"] "," gpu[gpu_id,"TEMP"] "," gpu[gpu_id,"FAN"]
        }
	
	if (TRACE != 0) { 
	print "SYSTEM NAME: " rig_name
	print "\tETH CURRENT HASHRATE: " current_hashrate_eth
	print "\tETH AVERAGE HASHRATE ETH: " average_hashrate_eth
	print "\tETH TOTAL SHARES: " total_shares_eth
	print "\tETH REJECTED SHARES: " rejected_shares_eth
	print "\tDCR/SC/LBC/PASC CURRENT HASHRATE: " current_hashrate_dcoin
	print "\tDCR/SC/LBC/PASC AVERAGE HASHRATE: " average_hashrate_dcoin
	print "\tDCR/SC/LBC/PASC TOTAL SHARES: " total_shares_dcoin
	print "\tDCR/SC/LBC/PASC REJECTED SHARES: " rejected_shares_dcoin
	print "\tPOWER USAGE: " power_usage
	print "\tETH MINING TIME: " mining_time
	print "\tETH DAG #: " dag ", DAG SIZE: " dag_size

	for ( i = 0; i < GPU_INDEX; i++ ) {
		print "GPU#" i
		print "\tETH HASHRATE: " gpu[i,"HASHRATE_ETH"]
		print "\tETH SHARES: " gpu[i,"SHARES_ETH"]
		print "\tETH INCORRECT_SHARES: " gpu[i,"INC_SHARES_ETH"]
		print "\tDCR/SC/LBC/PASC HASHRATE: " gpu[i,"HASHRATE_DCOIN"]
		print "\tDCR/SC/LBC/PASC SHARES: " gpu[i,"SHARES_DCOIN"]
		print "\tDCR/SC/LBC/PASC INCORRECT SHARES: " gpu[i,"INC_SHARES_DCOIN"]
		print "\tTEMP.(C): " gpu[i,"TEMP"]
		print "\tFAN SPEED: " gpu[i,"FAN"]
	}
	}
}

