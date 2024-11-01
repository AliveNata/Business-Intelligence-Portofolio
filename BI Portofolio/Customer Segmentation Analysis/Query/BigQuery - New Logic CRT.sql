SELECT cs.*, da.emails,
FROM `fact_crt_by_agent` cs
LEFT JOIN `dim_acc_cx_role` AS da -- ACL
    ON cs.venture = da.venture
    AND cs.shop_id = da.shop_id

INNER JOIN `dim_shop_info` AS dsi
    ON cs.shop_id = dsi.shop_id 
    AND cs.venture = dsi.venture
    AND cs.created_at >= dsi.cx_start_date
    AND cs.created_at <= (CASE WHEN dsi.cx_end_date IS NULL THEN '2099-01-01' ELSE dsi.cx_end_date END)
WHERE CASE WHEN cs.venture in ('TH', 'VN', 'ID') THEN CASE WHEN cs.venture = agent_venture THEN 'Yes' ELSE 'No' END 
ELSE 'Yes' END = 'Yes'
AND created_at >= PARSE_DATE('%Y%m%d', @DS_START_DATE)
AND created_at  <= PARSE_DATE('%Y%m%d', @DS_END_DATE)
AND REGEXP_CONTAINS(da.emails, @DS_USER_EMAIL)
