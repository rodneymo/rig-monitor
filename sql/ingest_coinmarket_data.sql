# 1504881599,MUSIC,Musicoin,0.00000565,EUR,0.0202646833,186089.925537,6539967.0
LOAD DATA LOCAL INFILE './tmp/coinmarket.tmp'
REPLACE
INTO TABLE rigdata.coinmarket
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(@_time,symbol,name,price_btc,quote_currency,price_quote_currency,volume_quote_currency,marketcap_quote_currency) SET time = FROM_UNIXTIME(@_time);

