
/*
 * This table will help FW understand the customer matching KPI on a daily basis. The table will have the following-
 * 1. date - daily level date column
 * 2. matched customers - daily level total customers with 1 or more transaction that were matched on either of the following
 * 	best_token
 * 	best_email
 * 	best_phone
 * 	best_cc_last_four
 * 	has_w1_email
 * 	no_w1_email	
 *  has_olo_email	
 *  no_olo_email
 * 3. Sum of binary count (1/0) on these columns 
* 	best_token
 * 	best_email
 * 	best_phone
 * 	best_cc_last_four
 * 	has_w1_email
 * 	no_w1_email	
 *  has_olo_email	
 *  no_olo_email
 * 4. All transactions
 * 5. Transactions that come from matched customers only
 * 6. All transactions
 * 7. % of transaction from customers with matching criteria over total transactions - matched customers / total transactions
 * KPI to be tracked by FW - match rate KPI for tracking matching customers overtime
 */

DECLARE @daily_date date
SET @daily_date = '2023-04-09'

; WITH rel_cust as 
(	
	SELECT DISTINCT fw_id
	,best_token
	,best_email
	,best_phone
	,best_cc_last_four
	FROM CustomerMatching.main.customer
	/*WHERE best_token IS NOT NULL
	OR best_email IS NOT NULL
	OR best_phone IS NOT NULL
	OR best_cc_last_four IS NOT NULL*/
),


customer_metrics as 
(
	SELECT DISTINCT
		fw_id,
		is_optin
	FROM CustomerMatching.main.customer_metrics 
),

-- 13.515 million customers - Grouped to customer level
summary as 
(
	SELECT a.business_date,
		a.fw_id,
		/*b.best_token,
		b.best_email,
		b.best_phone,
		b.best_cc_last_four,*/
		CASE WHEN b.best_token IS NOT NULL THEN 1 ELSE 0 END AS has_best_token,
		CASE WHEN b.best_email IS NOT NULL THEN 1 ELSE 0 END AS has_best_email,
		CASE WHEN b.best_phone IS NOT NULL THEN 1 ELSE 0 END AS has_best_phone,
		CASE WHEN b.best_cc_last_four IS NOT NULL THEN 1 ELSE 0 END AS has_best_cc_last_four,
		CASE WHEN a.w1_email IS NOT NULL THEN 1 ELSE 0 END AS has_w1_email,
		CASE WHEN a.olo_customer_email IS NOT NULL THEN 1 ELSE 0 END AS has_olo_email,
		CASE WHEN a.card_token IS NOT NULL THEN 1 ELSE 0 END AS has_card_token,
		c.is_optin,
		COUNT(*) as transactions,
		COUNT(DISTINCT unit_number) as stores, 
		COUNT(DISTINCT check_id) as checks
	FROM CustomerMatching.main.matched_transactions AS a
	INNER JOIN rel_cust b
	ON a.fw_id = b.fw_id
	INNER JOIN customer_metrics c
	ON b.fw_id = c.fw_id
	WHERE CAST(business_date as DATE) = DATEADD(DAY, -1, @daily_date)
	--BETWEEN @start_date AND @end_date 
			-- Limit to corporate stores
		AND unit_number NOT BETWEEN 500 AND 636 
		AND unit_number NOT BETWEEN 7629 AND 7710
		AND unit_number NOT IN (639, 641, 648, 701)
	GROUP BY a.fw_id, a.business_date, b.best_token, b.best_email, b.best_phone, b.best_cc_last_four, c.is_optin, a.w1_email, a.olo_customer_email, a.card_token
		
)


SELECT 
	business_date as today,
	sum(transactions) as transaction_total,
	COUNT(DISTINCT fw_id) as all_customers,
	COUNT(DISTINCT CASE WHEN has_best_token = 1 OR has_best_email = 1 OR has_best_phone = 1 OR has_best_cc_last_four = 1 THEN fw_id ELSE NULL END) as matched_customers,
	--sum(stores) as total_stores,
	sum(checks) as total_checks,
	sum(has_best_token) as best_token,
	sum(has_best_email) as best_email,
	sum(has_best_phone) as best_phone,
	sum(has_best_cc_last_four) as best_cc_last_four,
	sum(has_w1_email) as w1_email,
	sum(has_olo_email) as olo_email,
	sum(has_card_token) as card_token,
	--COUNT(DISTINCT CASE WHEN transactions = 1 THEN fw_id ELSE NULL END) as one_time,
	--COUNT(DISTINCT CASE WHEN transactions > 1 THEN fw_id ELSE NULL END) as repeat,
	--COUNT(DISTINCT CASE WHEN best_token IS NOT NULL THEN fw_id ELSE NULL END) as best_token_customer,	
	--COUNT(DISTINCT CASE WHEN best_email IS NOT NULL THEN fw_id ELSE NULL END) as best_email_customer,	
	--COUNT(DISTINCT CASE WHEN best_phone IS NOT NULL THEN fw_id ELSE NULL END) as best_phone_customer,	
	--COUNT(DISTINCT CASE WHEN best_cc_last_four IS NOT NULL THEN fw_id ELSE NULL END) as best_cc_last_four_customer,
	COUNT(DISTINCT CASE WHEN is_optin = 1 THEN fw_id ELSE NULL END) as optin_customers
FROM summary
GROUP BY business_date
ORDER BY 2 ASC




