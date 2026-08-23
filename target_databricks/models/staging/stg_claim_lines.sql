{# stg_claim_lines: FLATTEN claim line items, window SUM, conditional aggregation #}
{{ config(materialized='view', tags=['staging', 'billing']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.claim_id') AS STRING) AS claim_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.payer') AS STRING) AS payer_name,
  CAST(GET_JSON_OBJECT(li, '$.line_no') AS DECIMAL(38, 0)) AS line_number,
  CAST(GET_JSON_OBJECT(li, '$.cpt') AS STRING) AS cpt_code,
  CAST(GET_JSON_OBJECT(li, '$.units') AS DECIMAL(38, 0)) AS units,
  CAST(GET_JSON_OBJECT(li, '$.charge') AS DOUBLE) AS line_charge,
  CAST(GET_JSON_OBJECT(li, '$.paid') AS DOUBLE) AS line_paid,
  CAST(GET_JSON_OBJECT(li, '$.adjustment') AS DOUBLE) AS line_adjustment,
  CAST(GET_JSON_OBJECT(li, '$.denial_code') AS STRING) AS denial_code,
  IF(GET_JSON_OBJECT(li, '$.denial_code') IS NOT NULL, TRUE, FALSE) AS is_line_denied,
  SUM(CAST(GET_JSON_OBJECT(li, '$.charge') AS DOUBLE)) OVER (
    PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.claim_id') AS STRING)
    ORDER BY CAST(GET_JSON_OBJECT(li, '$.line_no') AS DECIMAL(38, 0)) ASC NULLS LAST
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS running_charge_total, /* Running total within claim */
  IF(
    CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE) = 0
    OR CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE) IS NULL,
    0,
    CAST(GET_JSON_OBJECT(li, '$.charge') AS DOUBLE) / CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE)
  ) AS pct_of_total, /* Percent of claim total */
  _ingested_at
FROM {{ source('landing', 'raw_claims') }}
  LATERAL VIEW EXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.line_items'), 'ARRAY<STRING>')) li_tbl AS li