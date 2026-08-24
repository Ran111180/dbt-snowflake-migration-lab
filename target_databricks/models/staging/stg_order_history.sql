{# stg_order_history: FLATTEN + RATIO_TO_REPORT for cost distribution #}
{{ config(materialized='view', tags=['staging', 'billing']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING) AS encounter_id,
  CAST(GET_JSON_OBJECT(f, '$.order_type') AS STRING) AS order_type,
  CAST(GET_JSON_OBJECT(f, '$.description') AS STRING) AS order_description,
  CAST(GET_JSON_OBJECT(f, '$.charge') AS DOUBLE) AS order_charge,
  f_pos + 1 AS order_sequence,
  (CAST(GET_JSON_OBJECT(f, '$.charge') AS DOUBLE)) / SUM(CAST(GET_JSON_OBJECT(f, '$.charge') AS DOUBLE)) OVER (PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING)) AS charge_pct_of_encounter,
  SUM(CAST(GET_JSON_OBJECT(f, '$.charge') AS DOUBLE)) OVER (PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING)) AS encounter_total_charges,
  _ingested_at
FROM {{ source('landing', 'raw_encounters') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.orders'), 'ARRAY<STRING>')) f_tbl AS f_pos, f
WHERE
  CAST(GET_JSON_OBJECT(f, '$.charge') AS DOUBLE) > 0