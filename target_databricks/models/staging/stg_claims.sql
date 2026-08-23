{# stg_claims: VARIANT arrays, FLATTEN line items, ZEROIFNULL, NULLIF #}
{{ config(materialized='view', tags=['staging', 'billing']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.claim_id') AS STRING) AS claim_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING) AS encounter_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.payer') AS STRING) AS payer_name,
  CAST(GET_JSON_OBJECT(raw_data, '$.claim_type') AS STRING) AS claim_type,
  CAST(GET_JSON_OBJECT(raw_data, '$.status') AS STRING) AS claim_status,
  TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.service_date') AS STRING) AS DATE) AS service_date,
  TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.submit_date') AS STRING) AS DATE) AS submit_date,
  TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.remit_date') AS STRING) AS DATE) AS remit_date,
  CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE) AS total_charges,
  CAST(GET_JSON_OBJECT(raw_data, '$.total_paid') AS DOUBLE) AS total_paid,
  IF(
    CAST(GET_JSON_OBJECT(raw_data, '$.total_denied') AS DOUBLE) IS NULL,
    0,
    CAST(GET_JSON_OBJECT(raw_data, '$.total_denied') AS DOUBLE)
  ) AS total_denied,
  CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE) - CAST(GET_JSON_OBJECT(raw_data, '$.total_paid') AS DOUBLE) - IF(
    CAST(GET_JSON_OBJECT(raw_data, '$.total_denied') AS DOUBLE) IS NULL,
    0,
    CAST(GET_JSON_OBJECT(raw_data, '$.total_denied') AS DOUBLE)
  ) AS outstanding_amount,
  IF(
    NULLIF(CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE), 0) = 0
    OR NULLIF(CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE), 0) IS NULL,
    0,
    CAST(GET_JSON_OBJECT(raw_data, '$.total_paid') AS DOUBLE) / NULLIF(CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE), 0)
  ) AS payment_ratio,
  DATEDIFF(
    DAY,
    TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.service_date') AS STRING) AS DATE),
    TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.submit_date') AS STRING) AS DATE)
  ) AS days_to_submit,
  IF(
    GET_JSON_OBJECT(raw_data, '$.remit_date') IS NOT NULL,
    DATEDIFF(
      DAY,
      TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.submit_date') AS STRING) AS DATE),
      TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.remit_date') AS STRING) AS DATE)
    ),
    NULL
  ) AS days_to_payment,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.line_items'), 'ARRAY<STRING>')) AS line_item_count,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.denial_reasons'), 'ARRAY<STRING>')) AS denial_reason_count,
  IF(CAST(GET_JSON_OBJECT(raw_data, '$.status') AS STRING) = 'Denied', TRUE, FALSE) AS is_denied,
  IF(CAST(GET_JSON_OBJECT(raw_data, '$.status') AS STRING) IN ('Paid', 'Partially Paid'), TRUE, FALSE) AS is_paid,
  _ingested_at
FROM {{ source('landing', 'raw_claims') }}