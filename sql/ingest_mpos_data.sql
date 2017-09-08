# 1504882048,MUSICOIN,getdashboarddata_stats,443736.135,180871746,890171119.91714,26911.498596191,0,0,83.04171047,25.1228189

LOAD DATA LOCAL INFILE './tmp/MPOS_getdashboarddata_stats.tmp'
INTO TABLE rigdata.mpos_stats
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(@_time,label,@empty,@_currentHashrate,@_poolHashrate,@_networkHashrate,valid_shares,invalid_shares,unpaid_shares,balance_confirmed,balance_unconfirmed) SET time = FROM_UNIXTIME(@_time), currentHashrate=@_currentHashrate/1000,poolHashrate=@_poolHashrate/1000,networkHashrate=@_poolHashrate/1000;

# 2017-08-26,MUSICOIN,getdashboarddata_payouts,1296.25062558

LOAD DATA LOCAL INFILE './tmp/MPOS_getdashboarddata_payouts.tmp'
REPLACE
INTO TABLE rigdata.mpos_payouts
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(@_date,label,@empty,amount) SET date = FROM_UNIXTIME(UNIX_TIMESTAMP(CONCAT(@_date," 0:0:0")));

