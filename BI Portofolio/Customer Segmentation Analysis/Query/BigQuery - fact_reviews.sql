-- Changelog:
-- 2023-06-21 by Alief: change dim_acl to dim_acl_cx_role (for CX Dashboard only)
-- 2023-09-26 by Alief: add processing_time bcs need partition in fact_reviews

SELECT
    fr.*except(unique_key, platform),
    da.brand_name, da.shop_name, da.platform,
	concat(da.shop_name, ' ', da.venture, ' - ', da.platform) AS shop_name_venture,
    cc.campaign_name, cc.campaign_type,
    da.count_gmv_for_int,
	da.use_cx_service,
    da.emails
FROM `fact_reviews` AS fr

LEFT JOIN `dim_campaign_calendar` AS cc -- Campaign Calendar
    ON fr.shop_id = cc.shop_id
    AND fr.venture = cc.venture
    AND fr.review_date = cc.period

JOIN `dim_acc_cx_role` AS da -- ACL
    ON fr.venture = da.venture
    AND fr.shop_id = da.shop_id

WHERE
    da.platform not in ('N/A')
    AND da.platform is not null
	AND fr.review_date between date_sub(date_trunc(current_date('+8:00'), YEAR), interval 1 YEAR) AND current_date('+8:00')
    AND date(fr.processing_time) >= '2022-01-01' 
    AND REGEXP_CONTAINS(da.emails, @DS_USER_EMAIL)
    AND fr.review_date >= PARSE_DATE('%Y%m%d', @DS_START_DATE)
	AND fr.review_date <= PARSE_DATE('%Y%m%d', @DS_END_DATE)