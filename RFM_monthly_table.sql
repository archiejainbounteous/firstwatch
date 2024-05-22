	DECLARE @month_start date
	SET @month_start = '2023-03-01'
	
	;WITH rel_cust as 
	(	
		SELECT DISTINCT fw_id
		FROM CustomerMatching.main.customer
		WHERE (
			--best_token IS NOT NULL
			--OR best_email IS NOT NULL
			--OR best_phone IS NOT NULL
			best_cc_last_four IS NOT NULL
		)
	),
	
	customer_metrics as 
	(
		SELECT DISTINCT
			fw_id,
			is_optin
		FROM CustomerMatching.main.customer_metrics 
	),
	
	summary as 
	(		
		SELECT
			DATEADD(DAY, -364, EOMONTH(@month_start, 0)) as start_date,
			EOMONTH(@month_start, 0) as end_date,
			m.fw_id,
			cm.is_optin,
			CAST(MAX(business_date) as DATE) as last_date,
			COUNT(*) as transactions,
			SUM(amount) as total_revenue,
			DATEDIFF(day, CAST(MAX(business_date) as DATE), EOMONTH(@month_start, 0)) as recency,
			COUNT(distinct unit_number) as units_visited
		FROM CustomerMatching.main.matched_transactions m
		INNER JOIN rel_cust r ON m.fw_id = r.fw_id
		INNER JOIN customer_metrics cm ON m.fw_id = cm.fw_id
		WHERE CAST(business_date as DATE) BETWEEN 
			DATEADD(DAY, -364, EOMONTH(@month_start, 0))
			AND  EOMONTH(@month_start, 0)
			-- Limit to corporate stores
			AND unit_number NOT BETWEEN 500 AND 636 
			AND unit_number NOT BETWEEN 7629 AND 7710
			AND unit_number NOT IN (639, 641, 648, 701)
		GROUP BY m.fw_id, cm.is_optin
			
	)
	,

rfm_optins as (SELECT 
	year_month,
	cluster,
	count(distinct fw_id) AS customer_count_email_optins
FROM
(SELECT 
concat(DATEPART(YEAR, end_date), '-', DATEPART(MONTH, end_date)) as year_month,
CASE WHEN transactions <= 1.50 AND DATEDIFF(day, last_date, end_date) <= 120.50  THEN '1_trip_recent'  
	 WHEN transactions <= 1.50 AND DATEDIFF(day, last_date, end_date) > 120.50 AND DATEDIFF(day, last_date, end_date) <= 271.50 THEN '1_trip_at_risk'  
	 WHEN transactions <= 1.50 AND DATEDIFF(day, last_date, end_date) > 271.50 THEN '1_trip_dormant'  
	 WHEN transactions > 1.50 AND transactions <= 2.50 AND DATEDIFF(day, last_date, end_date) <= 120.50 AND total_revenue <= 84.78 THEN '2_trip_recent'  
	 WHEN transactions > 1.50 AND transactions <= 2.50 AND DATEDIFF(day, last_date, end_date) <= 120.50 AND total_revenue > 84.78 THEN '2_trip_recent_highvalue'  
	 WHEN transactions > 1.50 AND transactions <= 2.50 AND DATEDIFF(day, last_date, end_date) > 120.50 THEN '2_trip_at_risk' 
	 WHEN transactions > 2.50 AND transactions <= 5.50 THEN '3to5_trips' 
	 WHEN transactions > 5.50 THEN '6plus_trips' 
	 ELSE 'other' END cluster, 
	 fw_id
FROM summary
WHERE is_optin = 1
) as t1
GROUP BY 
	year_month,
	t1.cluster
),

rfm as (SELECT 
	year_month,
	cluster,
	count(distinct fw_id) AS customer_count,
	avg(transactions) as avg_transactions,
	avg(total_revenue) as avg_revenue,
	avg(recency) as avg_recency
FROM
(SELECT 
concat(DATEPART(YEAR, end_date), '-', DATEPART(MONTH, end_date)) as year_month,
CASE WHEN transactions <= 1.50 AND DATEDIFF(day, last_date, end_date) <= 120.50  THEN '1_trip_recent'  
	 WHEN transactions <= 1.50 AND DATEDIFF(day, last_date, end_date) > 120.50 AND DATEDIFF(day, last_date, end_date) <= 271.50 THEN '1_trip_at_risk'  
	 WHEN transactions <= 1.50 AND DATEDIFF(day, last_date, end_date) > 271.50 THEN '1_trip_dormant'  
	 WHEN transactions > 1.50 AND transactions <= 2.50 AND DATEDIFF(day, last_date, end_date) <= 120.50 AND total_revenue <= 84.78 THEN '2_trip_recent'  
	 WHEN transactions > 1.50 AND transactions <= 2.50 AND DATEDIFF(day, last_date, end_date) <= 120.50 AND total_revenue > 84.78 THEN '2_trip_recent_highvalue'  
	 WHEN transactions > 1.50 AND transactions <= 2.50 AND DATEDIFF(day, last_date, end_date) > 120.50 THEN '2_trip_at_risk' 
	 WHEN transactions > 2.50 AND transactions <= 5.50 THEN '3to5_trips' 
	 WHEN transactions > 5.50 THEN '6plus_trips' 
	 ELSE 'other' END cluster, 
	 fw_id,
	 transactions,
	 total_revenue,
	 recency
FROM summary
) as t1
GROUP BY 
	year_month ,
	t1.cluster
)

SELECT a.year_month, a.cluster,  b.customer_count, b.avg_transactions, round(b.avg_revenue,2) as avg_revenue, b.avg_recency, a.customer_count_email_optins 
FROM rfm_optins a
INNER JOIN rfm b 
ON a.year_month = b.year_month 
AND a.cluster = b.cluster 






	