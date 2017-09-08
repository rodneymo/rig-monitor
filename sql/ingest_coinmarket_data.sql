LOAD DATA LOCAL INFILE './tmp/coinmarket.tmp'
REPLACE
INTO TABLE rigdata.coinmarket
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(@_time,symbol,name,price_btc,quote_currency,price_quote_currency,volume_quote_currency,marketcap_quote_currency) SET time = FROM_UNIXTIME(@_time);

