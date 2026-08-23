{# stg_diagnoses: LATERAL FLATTEN on array, QUALIFY, ROW_NUMBER, TRY_CAST #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(f, '$.icd10') AS STRING) AS icd10_code,
  CAST(GET_JSON_OBJECT(f, '$.description') AS STRING) AS diagnosis_description,
  CAST(GET_JSON_OBJECT(f, '$.is_primary') AS BOOLEAN) AS is_primary,
  TRY_CAST(CAST(GET_JSON_OBJECT(f, '$.onset') AS STRING) AS DATE) AS onset_date,
  CAST(GET_JSON_OBJECT(f, '$.severity') AS STRING) AS severity,
  f_pos + 1 AS diagnosis_sequence,
  CAST(GET_JSON_OBJECT(raw_data, '$.admit_date') AS DATE) AS admit_date,
  DATEDIFF(
    DAY,
    TRY_CAST(CAST(GET_JSON_OBJECT(f, '$.onset') AS STRING) AS DATE),
    CAST(GET_JSON_OBJECT(raw_data, '$.admit_date') AS DATE)
  ) AS days_before_admission,
  IF(CAST(GET_JSON_OBJECT(f, '$.is_primary') AS BOOLEAN), 'Primary', 'Secondary') AS diagnosis_type,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.diagnoses'), 'ARRAY<STRING>')) f_tbl AS f_pos, f
QUALIFY
  ROW_NUMBER() OVER (
    PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING), CAST(GET_JSON_OBJECT(f, '$.icd10') AS STRING)
    ORDER BY _ingested_at DESC NULLS FIRST
  ) = 1