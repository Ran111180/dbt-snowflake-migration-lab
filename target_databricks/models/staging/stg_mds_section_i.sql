{# stg_mds_section_i: FLATTEN Section I diagnoses from MDS assessment #}
{{ config(materialized='view', tags=['staging', 'mds']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(dx AS STRING) AS section_i_icd10,
  dx_pos + 1 AS diagnosis_position,
  'Section_I' AS mds_section,
  CAST(GET_JSON_OBJECT(raw_data, '$.mds_assessment.nursing_tier') AS STRING) AS nursing_tier,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.mds_assessment.section_i'), 'ARRAY<STRING>')) dx_tbl AS dx_pos, dx