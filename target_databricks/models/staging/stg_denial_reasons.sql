{# stg_denial_reasons: FLATTEN denial reasons array, REGEXP_REPLACE #}
{{ config(materialized='view', tags=['staging', 'billing']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.claim_id') AS STRING) AS claim_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.payer') AS STRING) AS payer_name,
  CAST(dr AS STRING) AS denial_reason_raw,
  REGEXP_REPLACE(CAST(dr AS STRING), '[^a-zA-Z0-9 ]', '') AS denial_reason_clean,
  UPPER(TRIM(CAST(dr AS STRING))) AS denial_reason_normalized,
  dr_pos + 1 AS denial_sequence,
  CAST(GET_JSON_OBJECT(raw_data, '$.total_denied') AS DOUBLE) AS denied_amount,
  CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE) AS total_charges,
  IF(
    CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE) = 0
    OR CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE) IS NULL,
    0,
    CAST(GET_JSON_OBJECT(raw_data, '$.total_denied') AS DOUBLE) / CAST(GET_JSON_OBJECT(raw_data, '$.total_charges') AS DOUBLE)
  ) AS denial_rate,
  _ingested_at
FROM {{ source('landing', 'raw_claims') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.denial_reasons'), 'ARRAY<STRING>')) dr_tbl AS dr_pos, dr
WHERE
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.denial_reasons'), 'ARRAY<STRING>')) > 0