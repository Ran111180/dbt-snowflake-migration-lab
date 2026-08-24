{# stg_discharge_meds: FLATTEN + REGEXP_LIKE for medication filtering #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING) AS encounter_id,
  CAST(GET_JSON_OBJECT(f, '$.drug_name') AS STRING) AS medication_name,
  CAST(GET_JSON_OBJECT(f, '$.dose') AS STRING) AS dose,
  CAST(GET_JSON_OBJECT(f, '$.frequency') AS STRING) AS frequency,
  CAST(GET_JSON_OBJECT(f, '$.route') AS STRING) AS route,
  IF(
    REGEXP_LIKE(CAST(GET_JSON_OBJECT(f, '$.drug_name') AS STRING), '(?i).*(statin|atorvastatin|rosuvastatin).*'),
    TRUE,
    FALSE
  ) AS is_statin,
  IF(
    REGEXP_LIKE(CAST(GET_JSON_OBJECT(f, '$.drug_name') AS STRING), '(?i).*(pril|sartan).*'),
    TRUE,
    FALSE
  ) AS is_ace_arb,
  IF(REGEXP_LIKE(CAST(GET_JSON_OBJECT(f, '$.drug_name') AS STRING), '(?i).*(olol|dilol).*'), TRUE, FALSE) AS is_beta_blocker,
  IF(REGEXP_LIKE(CAST(GET_JSON_OBJECT(f, '$.route') AS STRING), '(?i)^(IV|IM|SubQ)$'), TRUE, FALSE) AS is_injectable,
  f_pos + 1 AS medication_seq,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.discharge_medications'), 'ARRAY<STRING>')) AS total_discharge_meds,
  _ingested_at
FROM {{ source('landing', 'raw_encounters') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.discharge_medications'), 'ARRAY<STRING>')) f_tbl AS f_pos, f