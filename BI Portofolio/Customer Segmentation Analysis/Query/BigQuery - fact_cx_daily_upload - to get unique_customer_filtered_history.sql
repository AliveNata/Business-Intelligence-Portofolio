-- Change Log
-- 2024-05-15: Take out cx_brand_mapping cte

SELECT
    DATETIME(aa.date_input) timestamp,
	aa.date_input as data_date,
    aa.venture,
	aa.shift,
    upper(aa.platform_name) platform,
    IF(cdl.brand_name IS NULL,aa.brand_name, cdl.log_brand_name) AS brand_name,
    aa.agent_name,
    aa.chat_type,
    aa.customer_name,
    concat(COALESCE(cdl.brand_name, dsi.shop_name, aa.brand_name), ' ', aa.venture, ' - ', upper(aa.platform_name)) AS shop_name_venture,
    -- concat(upper(aa.brand_name), ' ', aa.venture, ' - ', upper(aa.platform_name)) AS shop_name_venture,
    CASE WHEN aa.chat_type not in ('Rating - Product Negative', 'Rating - Product Positive', 'Rating - Seller Negative','Rating - Seller Positive','Rating - Logistic Positive', 'Rating - Logistic Negative','Blast Promo','Blast Unpaid','Discussion','Outbound Call') THEN lower(trim(aa.customer_name)) ELSE NULL END AS customer_name_filtered,
    aa.processing_time
FROM    (SELECT 
        'ID' as venture, *
    FROM `fact_cx_daily_upload_id_history`
    WHERE date_input between date_sub(date_trunc(current_date('+8:00'), YEAR), interval 2 YEAR) AND current_date('+8:00') 
    ) aa
LEFT JOIN `fact_cx_daily_upload` AS cdl ON aa.brand_name = cdl.brand_name and aa.venture = cdl.venture
JOIN `dim_acc_cx_role` AS da -- ACL
    ON aa.venture = da.venture
LEFT JOIN `dim_shop_info` dsi ON upper(aa.brand_name) = dsi.brand_name and aa.venture = dsi.venture

WHERE
	REGEXP_CONTAINS(da.emails, @DS_USER_EMAIL)
  AND aa.date_input >= PARSE_DATE('%Y%m%d', @DS_START_DATE)
	AND aa.date_input <= PARSE_DATE('%Y%m%d', @DS_END_DATE)
