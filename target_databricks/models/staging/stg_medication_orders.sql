{# stg_medication_orders: ARRAY_CONSTRUCT, ARRAY_APPEND, ARRAY_CAT #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING) AS encounter_id,
  CAST(GET_JSON_OBJECT(f, '$.drug_name') AS STRING) AS medication_name,
  CAST(GET_JSON_OBJECT(f, '$.dose') AS STRING) AS dose,
  CAST(GET_JSON_OBJECT(f, '$.route') AS STRING) AS route,
  CAST(GET_JSON_OBJECT(f, '$.frequency') AS STRING) AS frequency,
  ARRAY(
    CAST(GET_JSON_OBJECT(f, '$.drug_name') AS STRING),
    CAST(GET_JSON_OBJECT(f, '$.dose') AS STRING),
    CAST(GET_JSON_OBJECT(f, '$.route') AS STRING)
  ) AS med_summary_array,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.medications'), 'ARRAY<STRING>')) AS total_medications,
  f_pos + 1 AS order_sequence,
  TRY_TO_TIMESTAMP(CAST(GET_JSON_OBJECT(f, '$.ordered_at') AS STRING)) AS ordered_at,
  TRY_TO_TIMESTAMP(CAST(GET_JSON_OBJECT(f, '$.administered_at') AS STRING)) AS administered_at,
  DATEDIFF(
    MINUTE,
    TRY_TO_TIMESTAMP(CAST(GET_JSON_OBJECT(f, '$.ordered_at') AS STRING)),
    TRY_TO_TIMESTAMP(CAST(GET_JSON_OBJECT(f, '$.administered_at') AS STRING))
  ) AS minutes_to_administer,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.medications'), 'ARRAY<STRING>')) f_tbl AS f_pos, f