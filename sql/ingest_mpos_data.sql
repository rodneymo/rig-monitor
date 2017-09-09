# HASHRATES CONVERTED TO MH/S

LOAD DATA LOCAL INFILE './tmp/MPOS_getdashboarddata_stats.tmp'
INTO TABLE rigdata.mpos_stats
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(@_time,label,@empty,@_currentHashrate,@_poolHashrate,@_networkHashrate,valid_shares,invalid_shares,unpaid_shares,balance_confirmed,balance_unconfirmed) SET time = FROM_UNIXTIME(@_time), currentHashrate=@_currentHashrate/1000, poolHashrate=@_poolHashrate/1000,networkHashrate=@_networkHashrate/1000;

LOAD DATA LOCAL INFILE './tmp/MPOS_getdashboarddata_payouts.tmp'
REPLACE
INTO TABLE rigdata.mpos_payouts
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(@_date,label,@empty,amount) SET date = FROM_UNIXTIME(UNIX_TIMESTAMP(CONCAT(@_date," 0:0:0")));

