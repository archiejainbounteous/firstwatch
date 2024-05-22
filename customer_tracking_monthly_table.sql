/* This table captures monthly updates for following
 * 1. One time customers
 * 2. Repeat customers
 * 3. Total matched customers
 * 4. % of 
 * */


DECLARE @month_start date
SET @month_start = '2023-03-01'

;WITH rel_cust as 
(	
	SELECT DISTINCT fw_id
	FROM CustomerMatching.main.customer
	WHERE best_token IS NOT NULL 
		OR best_email IS NOT NULL
		OR best_phone IS NOT NULL
		OR best_cc_last_four IS NOT NULL
),

summary as 
(		
	SELECT
	fw_id, 
	COUNT(*) as transactions
	FROM CustomerMatching.main.matched_transactions
	WHERE CAST(business_date as DATE) BETWEEN 
		DATEADD(DAY, -364, EOMONTH(@month_start, 0))
		AND  EOMONTH(@month_start, 0)
	GROUP BY fw_id
		
),

last_mo_users as 
(
	SELECT 
	DISTINCT a.fw_id
	FROM CustomerMatching.main.matched_transactions a
	INNER JOIN rel_cust b
	ON a.fw_id = b.fw_id
	WHERE CAST(business_date as DATE) BETWEEN 
		@month_start
		AND EOMONTH(@month_start, 0)
	GROUP BY a.fw_id
),

analysis_users as 
(
	SELECT 
		b.*
	FROM last_mo_users a
	INNER JOIN summary b
	ON a.fw_id = b.fw_id
)


SELECT 
	MAX(@month_start) as year_month,
	sum(transactions) as transactions,
	COUNT(DISTINCT CASE WHEN transactions = 1 THEN fw_id ELSE NULL END) as one_time,
	COUNT(DISTINCT CASE WHEN transactions > 1 THEN fw_id ELSE NULL END) as repeat
	--sum(COUNT(DISTINCT CASE WHEN transactions = 1 THEN fw_id ELSE NULL END), COUNT(DISTINCT CASE WHEN transactions > 1 THEN fw_id ELSE NULL END)) as total_customers
	--COUNT(DISTINCT CASE WHEN transactions = 1 THEN fw_id ELSE NULL END)/ (sum(COUNT(DISTINCT CASE WHEN transactions = 1 THEN fw_id ELSE NULL END), COUNT(DISTINCT CASE WHEN transactions > 1 THEN fw_id ELSE NULL END) *100 as test
FROM analysis_users
-- GROUP BY @month_start



