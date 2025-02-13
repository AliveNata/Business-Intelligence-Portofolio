-- ** Change Log **--
-- 2023-02-07 by My: Mapping daily log brand short names with PWH brand name
-- 2023-02-09 by Alief : added IF(cbm.pwh_brand_name IS NULL,dl.brand_name,cbm.pwh_brand_name) AS brand_name and dl.venture = cbm.venture 
-- 2023-03-16 by Alief : added shop_name & brand_name column in emails cte then use column from emails to showing value from SC  
-- 2023-06-21 by Alief: change dim_acl to dim_acl_cx_role (for CX Dashboard only)
-- 2023-09-28 by Alief : case when tiktok shop to tiktok
-- 2023-12-03 by Alief : take cx_brand_mapping bcs brand mapping logic was applied in fact_cx_daily_log_chat_type

with emails AS (
  SELECT distinct
  	venture,
    STRING_AGG(distinct emails, ',') AS emails
  FROM `dim_acl_cx_role` 
  group by 1
)


SELECT
    dl.* except (platform),
    upper(case when dl.platform = 'tiktok shop' then 'tiktok'
      else dl.platform end) AS Platform,
    concat(dl.brand_name, ' ', dl.venture, ' - ', upper(dl.platform)) AS shop_name_venture,
    CONCAT(dl.brand_name, ' - ', UPPER(dl.platform)) AS shop_name_platform,
    da.emails
FROM `fact_cx_daily_upload_chat_type` AS dl
JOIN emails da ON dl.venture = da.venture
LEFT JOIN `dim_shop_info` dsi ON dl.shop_id = dsi.shop_id

WHERE
  dl.platform is not null	
  AND lower(dl.platform) not in ('n/a')
  --AND (dsi.pws_shop_status='active' OR dl.shop_id IS NULL)
	AND REGEXP_CONTAINS(da.emails, @DS_USER_EMAIL)
	AND dl.data_date >= PARSE_DATE('%Y%m%d', @DS_START_DATE)
	AND dl.data_date <= PARSE_DATE('%Y%m%d', @DS_END_DATE)

