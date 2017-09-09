LOAD DATA LOCAL INFILE './tmp/NANOPOOL_generalinfo.tmp'
INTO TABLE rigdata.nanopool_generalinfo
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(@_time,label,@empty,currentHashrate,avgHashrate_h1,avgHashrate_h3,avgHashrate_h6,avgHashrate_h12,avgHashrate_h24,balance,unconfirmed_balance) SET time = FROM_UNIXTIME(@_time);

# 1469876484,NANOPOOL,payments,e96f266cdce605f717999b582fbf195a5dc2b650367ee2ee1b090d1ceb253551,5061,true
LOAD DATA LOCAL INFILE './tmp/NANOPOOL_payments.tmp'
REPLACE
INTO TABLE rigdata.nanopool_payouts
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(@_date,label,@empty,amount,txHash,confirmed) SET date = FROM_UNIXTIME(@_date);

