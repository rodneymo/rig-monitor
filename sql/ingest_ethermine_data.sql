#1504881000,ETHERMINE,currentStats,1504880998,247384840,254333333.33333334,225,0,6,243624614.1975308,4,37668876799305976,,2.97940102959064e-05,0.008985575565142411,2.0691940150506996e-06

LOAD DATA LOCAL INFILE './tmp/ETHERMINE_ethermine_stats.tmp'
INTO TABLE rigdata.ethermine_stats
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(@_time,label,@_empty,@_lastseen, @_reportedHashrate,@_currentHashrate,valid_shares,invalid_shares,stale_shares,@_averageHashrate,activeWorkers,@_unpaid,unconfirmed,coinsPerMin,usdPerMin,btcPerMin) 
SET time = FROM_UNIXTIME(@_time),lastseen = FROM_UNIXTIME(@_lastseen), reportedHashrate=@_reportedHashrate/1E6, currentHashrate=@_currentHashrate/1E6, averageHashrate=@_averageHashrate/1E6, unpaid=@_unpaid/1E18;

#1504811099,ETHERMINE,payouts,4245154,4248924,49167745469264490,0xd009b7d412bd1ba3438cf960eb94d38edefefd24c96b93cc4c1d68248c1b1164

LOAD DATA LOCAL INFILE './tmp/ETHERMINE_ethermine_payouts.tmp'
REPLACE
INTO TABLE rigdata.ethermine_payouts
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(@_paidon,label,@empty,start,end,@_amount,txHash) SET paidon = FROM_UNIXTIME(@_paidon), amount = @_amount/1E18;

