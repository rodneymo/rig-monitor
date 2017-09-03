LOAD DATA LOCAL INFILE './tmp/ethermine_payouts.tmp'
INTO TABLE rigdata.ethermine_payouts
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(@var1,start,end,@var2,txHash) SET paidon = FROM_UNIXTIME(@var1), amount = @var2/1E18;

LOAD DATA LOCAL INFILE './tmp/ethermine_stats.tmp'
INTO TABLE rigdata.ethermine_stats
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
(@var1,@var2,@var3,@var4,valid_shares,invalid_shares,stale_shares,@var5,activeWorkers,@var6,unconfirmed,coinsPerMin,usdPerMin,btcPerMin) 
SET time = FROM_UNIXTIME(@var1), lastseen = FROM_UNIXTIME(@var2), reportedHashrate=@var3/1E6, currentHashrate=@var4/1E6, averageHashrate=@var5/1E6, unpaid=@var6/1E18;

