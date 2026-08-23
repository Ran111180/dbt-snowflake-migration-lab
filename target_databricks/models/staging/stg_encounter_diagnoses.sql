{# stg_encounter_diagnoses: FLATTEN diagnosis_codes array from encounters #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING) AS encounter_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(dx AS STRING) AS icd10_code,
  dx_pos + 1 AS diagnosis_rank,
  IF(dx_pos = 0, TRUE, FALSE) AS is_primary,
  CAST(GET_JSON_OBJECT(raw_data, '$.encounter_type') AS STRING) AS encounter_type,
  TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.admit_datetime') AS STRING) AS DATE) AS encounter_date,
  _ingested_at
FROM {{ source('landing', 'raw_encounters') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.diagnosis_codes'), 'ARRAY<STRING>')) dx_tbl AS dx_pos, dx