# 1504881471,NANOPOOL,generalinfo,200724.0,208980.0,207876.3,208069.8,207521.6,207985.6,603.09686796,0.00000000

LOAD DATA LOCAL INFILE './tmp/NANOPOOL_generalinfo.tmp'
INTO TABLE rigdata.nanopool_generalinfo
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(@_time,label,@empty,currentHashrate,avgHashrate_h1,avgHashrate_h3,avgHashrate_h6,avgHashrate_h12,avgHashrate_h24,balance,unconfirmed_balance) SET time = FROM_UNIXTIME(@_time);

# 1504874408,NANOPOOL,payments,f70eb3e904e61ae94b61bc7da85711089c394a6612e1979f6ff6ca63804ab4b0,1790,true

LOAD DATA LOCAL INFILE './tmp/NANOPOOL_payments.tmp'
REPLACE
INTO TABLE rigdata.nanopool_payouts
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(@_date,label,@empty,txHash,amount,confirmed) SET date = FROM_UNIXTIME(@_date);

