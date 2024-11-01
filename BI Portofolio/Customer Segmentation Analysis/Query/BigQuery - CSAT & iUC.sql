WITH raw AS (
  SELECT 
    
    /*     Added by Brandy Column: dl.actual_chat_date This is based on the agreement with Wahyu and product team to show the actual chat date instead of the date input
    .      Change log
           --2022-09-28 by: Alief Akbar upper(dl.brand_name) = si.shop_name to upper(dl.brand_name) = si.brand_name      because many shop_name_venture is null
           --2022-10-20 by: June added unique_conversation_filtered_rating & unique_conversation_filtered_rating as for Wahyu's request
           --2023-03-22 by: Alief Akbar added unique_customer_name_filtered for define data
           --2023-06-28 by: Alief Akbar adjust logic unique_customer_name_filtered use count distinct
           --2023-10-26 by: Alief Akbar Tokopedia - Order Complaint dan Tokopedia - Support Message chat type include iUC
           --2023-12-03 by: Alief Akbar Adjust brand mapping brand name with 2 logics (if have shop id from daily log will be join to shop id dim_shop_info, if not available will be join to cx mapping sheet list)

    */
    COALESCE(
      dl.actual_chat_date, dl.date_input
    ) AS data_date, 
    dl.shop_id, 
    brand_name shop_name, 
    -- si.count_gmv_for_int, 
    dl.platform_name AS platform, 
    dl.log_brand_name,
    upper(dl.brand_name) brand_name,
    dl.* 
  EXCEPT 
    (
      date_input, brand_name, platform_name, 
      chat_type, shop_id, log_brand_name
    ), 
    chat_type, 
    CASE WHEN REGEXP_CONTAINS(dl.chat_type, ' - ') = TRUE THEN SPLIT(dl.chat_type, ' - ') [ OFFSET (0) ] ELSE dl.chat_type END AS chat_type_level_1, 
    CASE WHEN REGEXP_CONTAINS(dl.chat_type, ' - ') = FALSE THEN NULL ELSE RIGHT(dl.chat_type, LENGTH(dl.chat_type) - STRPOS(dl.chat_type, ' - ') -2) END AS chat_type_level_2, 
    IF (LOWER(TRIM(dl.extra_mile)) = 'yes', 1, 0) AS is_extra_mile, 
    cc.campaign_name, 
    cc.campaign_type 
  FROM 
    (
      SELECT 
        * 
      FROM 
        `fact_cx_daily_upload` 
      WHERE 
        date_input >= "2022-01-01" 
        
       
    ) dl 
    -- LEFT JOIN `dim_shop_info` AS si ON --dl.venture = si.venture  --Tina remove this mapping because venture from daily log can be wrong as it's manual.
    -- AND UPPER(dl.brand_name) = si.brand_name 
    -- dl.shop_id = si.shop_id -- shop id is unique so only this mapping should be ok
    -- AND dl.platform_name = si.platform_norm --Tina remove this mapping because platform from daily can be wrong as it's manual
    -- AND dl.date_input BETWEEN si.start_date --Tina remove due to not necessary
    -- AND si.end_date 
    LEFT JOIN `dim_campaign_calendar` AS cc ON dl.shop_id = cc.shop_id 
    AND dl.venture = cc.venture 
    AND dl.date_input = cc.period
) 


, iuc as
(
SELECT 
  TO_HEX(
    MD5(
      CONCAT(
        venture, data_date, shift, brand_name,
        chat_type_level_1, agent_initial 
      )
    )
  ) AS unique_key, 
  *, 
  CURRENT_DATETIME() AS processing_time 
FROM 
  (
    SELECT 
      data_date, 
      rw.venture, 
      upper(platform) platform,
      rw.shop_id, 
      shop_name,
      -- upper(IF(rw.shop_id IS NULL,bm.pwh_brand_name, rw.brand_name)) AS brand_name,
      --upper(case when rw.shop_id is null then bm.pwh_brand_name
        --when rw.shop_id is not null then rw.brand_name end) AS brand_name,
        upper(rw.brand_name) as brand_name,
        Upper(rw.log_brand_name) log_brand_name ,
      -- brand_name, 
      -- count_gmv_for_int, 
      campaign_name, 
      campaign_type, 
      shift, 
      chat_type_level_1, 
      chat_type_level_2, 
      agent_name agent_initial, 
      COUNT(*) AS unique_conversation, 
      COUNT(
        CASE WHEN chat_type NOT IN (
          'Rating - Product Negative', 'Rating - Product Positive', 
          'Rating - Seller Negative', 'Rating - Seller Positive', 
          'Rating - Logistic Positive', 'Rating - Logistic Negative', 
          'Blast Promo', 'Blast Unpaid', 'Discussion',  
          'Outbound Call'
        ) THEN 1 ELSE NULL END
      ) AS unique_conversation_filtered, 
      COUNT(
        CASE WHEN chat_type IN ('Blast Promo', 'Blast Unpaid') THEN 1 ELSE NULL END
      ) AS unique_conversation_filtered_blast, 
      COUNT(
        CASE WHEN chat_type IN (
          'Rating - Product Negative', 'Rating - Product Positive', 
          'Rating - Seller Negative', 'Rating - Seller Positive', 
          'Rating - Logistic Positive', 'Rating - Logistic Negative'
        ) THEN 1 ELSE NULL END
      ) AS unique_conversation_filtered_rating, 
      COUNT(DISTINCT customer_name) AS unique_customer, 
      COUNT(
        DISTINCT (
          CASE WHEN chat_type NOT IN (
            'Rating - Product Negative', 'Rating - Product Positive', 
            'Rating - Seller Negative', 'Rating - Seller Positive', 
            'Rating - Logistic Positive', 'Rating - Logistic Negative', 
            'Blast Promo', 'Blast Unpaid', 'Discussion', 
            'Outbound Call'
          ) THEN customer_name ELSE NULL END
        )
      ) AS unique_customer_name_filtered, 
      SUM(is_extra_mile) AS extra_mile, 
      MAX(rw.processing_time) AS last_update 
    FROM 
      raw rw
      where data_date >= "2023-01-01"
      -- and venture = 'ID'
      -- LEFT JOIN `cx_brand_mapping` bm on rw.venture = bm.venture and upper(rw.log_brand_name) = upper(bm.pws_brand_name) -- Tina revised
	  --  Where brand_name in ('LANEIGE', 'MISE EN SCENE', 'SULWHASOO')
     GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
     ORDER BY 1, 2 asc
  )
)



, csat as 
(
select 
  cx.created_at data_date,
  -- message_id,
  -- session_id,
  agent_initial,
  cx.venture,
  case when si.brand_name = '3MOFFICIAL' then '3M'
    when si.brand_name ='HPOFFICIAL' then 'HP'
  else si.brand_name end as brand_name,
  upper(cx.platform) AS platform,
  count (*) csat_attempts,
  ifnull(sum(case when csat_bucket = '1' then 1 end),0) csat_1,
  ifnull(sum(case when csat_bucket = '2' then 1 end),0) csat_2,
  ifnull(sum(case when csat_bucket = 'IRRELEVANT' then 1 end),0) csat_irrelevant
  -- concat(upper(si.shop_name), ' ', cx.venture, ' - ', upper(cx.platform)) AS shop_name_venture  
from `fact_cx_chat_message` as cx
-- JOIN `dim_acc` AS da ON cx.venture = da.venture AND cx.shop_id = da.shop_id
JOIN `dim_shop_info` AS si ON cx.venture = si.venture AND cx.shop_id = si.shop_id
-- WHERE 
  -- REGEXP_CONTAINS(da.emails, @DS_USER_EMAIL)
  AND cx.platform not in ('N/A')
  AND cx.platform is not null
 AND cx.message_type = 'agent' 
-- AND lower(content) not like '%test%'
-- AND lower(content) <> 'tesst'
  --AND cx.created_at >= '2022-12-13'
AND cx.created_at >= "2023-01-01"
-- AND cx.venture = 'ID'
AND content_type = 'csat'
group by 1,2,3,4,5
ORDER BY 1,2,3,4
),

emails AS (
  SELECT distinct
  	venture,
    STRING_AGG(distinct emails, ',') AS emails
  FROM `dim_acc_cx_role` 
  group by 1
)

select
    iuc.data_date,
    iuc.agent_initial,
    iuc.brand_name,
  	iuc.venture,
    upper(iuc.platform) platform_upper,
    ifnull(csat_attempts, 0) csat_attempts,
    ifnull(csat_1, 0) csat_1,
  	ifnull(csat_2, 0) csat_2,
  	ifnull(csat_irrelevant, 0) csat_irrelevant,
    sum(unique_conversation_filtered) iuc
  from iuc
  left join csat on  iuc.data_date = csat.data_date and iuc.brand_name = csat.brand_name and iuc.agent_initial = csat.agent_initial and iuc.platform = csat.platform and iuc.venture = csat.venture
  join emails da ON iuc.venture = da.venture
  where regexp_contains(da.emails, @DS_USER_EMAIL)
  and iuc.data_date >= PARSE_DATE('%Y%m%d', @DS_START_DATE)
  and iuc.data_date <= PARSE_DATE('%Y%m%d', @DS_END_DATE)
  group by data_date,
           agent_initial,
           brand_name,
  	       venture,
           platform_upper,
           csat_attempts,
           csat_1,
           csat_2,
           csat_irrelevant
  order by 1,2,3
