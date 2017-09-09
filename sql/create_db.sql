CREATE DATABASE IF NOT EXISTS rigdata;

#CREATE USER IF NOT EXISTS 'grafana2'@localhost IDENTIFIED BY 'grafana';
GRANT SELECT ON `rigdata`.* TO `grafana`@`localhost` IDENTIFIED BY 'grafana';

CONNECT rigdata;

CREATE TABLE IF NOT EXISTS rigdata.info_rig(
	rig_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
	rig_name VARCHAR(10) NOT NULL,
	miner_sw VARCHAR(20) NOT NULL,
	ip_address VARCHAR(20) NOT NULL,
	plug_ip  VARCHAR(20) NOT NULL,
	installed_gpus INT NOT NULL,
	target_hashrate FLOAT(7,3) NOT NULL,
	target_hashrate_dcoin FLOAT(7,3) NOT NULL,
	target_temp INT NOT NULL,
	max_power INT NOT NULL
   );

CREATE TABLE IF NOT EXISTS rigdata.info_gpu(
	rig_gpu_id VARCHAR(12) NOT NULL,
	model VARCHAR(20) NOT NULL,
	memory  INT NOT NULL,
	processors INT NOT NULL
   );
   
CREATE TABLE IF NOT EXISTS rigdata.status_rig(
	time DATETIME,
	rig_name VARCHAR(10) NOT NULL,
	working_gpus INT NOT NULL,
	current_hashrate_eth FLOAT(7,3),
	average_hashrate_eth FLOAT(7,3),
	total_shares_eth INT,
	total_rej_shares_eth INT,
	current_hashrate_dcoin FLOAT(7,3),
	average_hashrate_dcoin FLOAT(7,3),
	total_shares_dcoin INT,
	total_rej_shares_dcoin INT,
	power_usage INT,
	mining_time TIME,
	PRIMARY KEY(time,rig_name)
   );
   
CREATE TABLE IF NOT EXISTS rigdata.status_gpu(
	time DATETIME,
	rig_gpu_id VARCHAR(12) NOT NULL,
	gpu_hashrate_eth FLOAT(7,3) NOT NULL,
	gpu_shares_eth INT NOT NULL,
	gpu_inc_shares_eth INT,
	gpu_hashrate_dcoin FLOAT(7,3) NOT NULL,
	gpu_shares_dcoin INT NOT NULL,
	gpu_inc_shares_dcoin INT,
	gpu_temp INT NOT NULL,
	gpu_fan INT NOT NULL,
	PRIMARY KEY(time,rig_gpu_id)
);

CREATE TABLE IF NOT EXISTS rigdata.ethermine_stats(
        time DATETIME,				-- time from json file
        label VARCHAR(100) NOT NULL,
        lastseen DATETIME,
        reportedHashrate FLOAT(20,3),
        currentHashrate FLOAT(20,3),
        valid_shares INT,
        invalid_shares INT,
        stale_shares INT,
        averageHashrate FLOAT(20,3),
        activeWorkers INT,
        unpaid FLOAT(18,16),
        unconfirmed FLOAT(18,16),
        coinsPerMin FLOAT(18,16),
        usdPerMin FLOAT(18,16),
        btcPerMin FLOAT(20,18),
        PRIMARY KEY(time,label)

);

CREATE TABLE IF NOT EXISTS rigdata.ethermine_payouts(
	time DATETIME,					-- runtime, execution date/time in system
        paidon DATETIME,			-- one entry per payment
        label VARCHAR(100) NOT NULL,
        start VARCHAR(12) NOT NULL,
        end VARCHAR(12) NOT NULL,
        amount FLOAT(18,16),
        txHash VARCHAR(100) NOT NULL,
        PRIMARY KEY(paidon,label)
);

CREATE TABLE IF NOT EXISTS rigdata.mpos_stats(
	time DATETIME,					-- runtime, execution date/time in system
	label VARCHAR(100) NOT NULL,
	currentHashrate FLOAT(20,3),
	poolHashrate FLOAT(20,3),
	networkHashrate FLOAT(20,3),
	valid_shares FLOAT(20,11),
	invalid_shares FLOAT(20,11),
	unpaid_shares FLOAT(20,11),
	balance_confirmed FLOAT(20,11),
	balance_unconfirmed FLOAT(20,11),
	PRIMARY KEY(time,label)
);

CREATE TABLE IF NOT EXISTS rigdata.mpos_payouts(
	time DATETIME,					-- runtime, execution date/time in system
	date DATETIME,						-- this is the unpaid amount, which will increase throughout the day
	label VARCHAR(100) NOT NULL,
	amount FLOAT(20,11),
	PRIMARY KEY(date,label)
);

CREATE TABLE IF NOT EXISTS rigdata.nanopool_generalinfo(
	time DATETIME,					-- runtime, execution date/time in system
	label VARCHAR(100) NOT NULL,
	currentHashrate FLOAT(20,3),
	avgHashrate_h1 FLOAT(20,3),
	avgHashrate_h3 FLOAT(20,3),
	avgHashrate_h6 FLOAT(20,3),
	avgHashrate_h12 FLOAT(20,3),
	avgHashrate_h24 FLOAT(20,3),
	balance FLOAT(20,11),
	unconfirmed_balance FLOAT(20,11),
	PRIMARY KEY(time,label)
);

CREATE TABLE IF NOT EXISTS rigdata.nanopool_payouts(
	time DATETIME,					-- runtime, execution date/time in system
	date DATETIME,						-- this is the unpaid amount, which will increase throughout the day
	label VARCHAR(100) NOT NULL,
	txHash VARCHAR(100) NOT NULL,
	amount FLOAT(20,11),
	confirmed VARCHAR(10) NOT NULL,
	PRIMARY KEY(date,label)
);

CREATE TABLE IF NOT EXISTS rigdata.coinmarket(
	time DATETIME,
	symbol VARCHAR(10) NOT NULL,
	name VARCHAR(100) NOT NULL,
	price_btc FLOAT(20,11),
	quote_currency VARCHAR(10) NOT NULL,
	price_quote_currency FLOAT(20,11),
	volume_quote_currency FLOAT(20,3),
	marketcap_quote_currency FLOAT(20,3),
	PRIMARY KEY(time,symbol)
);

