{# stg_primary_diagnosis: FLATTEN + QUALIFY + FIRST_VALUE #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(f, '$.icd10') AS STRING) AS primary_icd10,
  CAST(GET_JSON_OBJECT(f, '$.description') AS STRING) AS primary_diagnosis_desc,
  CAST(GET_JSON_OBJECT(f, '$.severity') AS STRING) AS severity,
  TRY_CAST(CAST(GET_JSON_OBJECT(f, '$.onset') AS STRING) AS DATE) AS onset_date,
  FIRST_VALUE(CAST(GET_JSON_OBJECT(f, '$.icd10') AS STRING)) OVER (
    PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING)
    ORDER BY IF(CAST(GET_JSON_OBJECT(f, '$.is_primary') AS BOOLEAN), 0, 1) ASC NULLS LAST, f_pos ASC NULLS LAST
  ) AS confirmed_primary_dx,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.diagnoses'), 'ARRAY<STRING>')) f_tbl AS f_pos, f
WHERE
  CAST(GET_JSON_OBJECT(f, '$.is_primary') AS BOOLEAN) = TRUE
QUALIFY
  ROW_NUMBER() OVER (
    PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING)
    ORDER BY _ingested_at DESC NULLS FIRST
  ) = 1