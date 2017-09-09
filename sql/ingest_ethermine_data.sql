LOAD DATA LOCAL INFILE './tmp/ETHERMINE_ethermine_stats.tmp'
INTO TABLE rigdata.ethermine_stats
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(@_time,label,@_empty,@_lastseen, @_reportedHashrate,@_currentHashrate,valid_shares,invalid_shares,stale_shares,@_averageHashrate,activeWorkers,@_unpaid,unconfirmed,coinsPerMin,usdPerMin,btcPerMin) 
SET time = FROM_UNIXTIME(@_time),lastseen = FROM_UNIXTIME(@_lastseen), reportedHashrate=@_reportedHashrate/1E6, currentHashrate=@_currentHashrate/1E6, averageHashrate=@_averageHashrate/1E6, unpaid=@_unpaid/1E18;

LOAD DATA LOCAL INFILE './tmp/ETHERMINE_ethermine_payouts.tmp'
REPLACE
INTO TABLE rigdata.ethermine_payouts
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(@_time,@_paidon,label,@empty,start,end,@_amount,txHash) SET time = FROM_UNIXTIME(@_time), paidon = FROM_UNIXTIME(@_paidon), amount = @_amount/1E18;

