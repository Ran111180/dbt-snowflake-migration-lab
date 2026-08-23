{# stg_mds_assessments: Nested VARIANT object access, ARRAY_TO_STRING #}
{{ config(materialized='view', tags=['staging', 'clinical', 'mds']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.mds_assessment.nursing_tier') AS STRING) AS nursing_tier,
  CAST(GET_JSON_OBJECT(raw_data, '$.mds_assessment.nta_tier') AS STRING) AS nta_tier,
  CAST(GET_JSON_OBJECT(raw_data, '$.mds_assessment.pt_tier') AS STRING) AS pt_tier,
  CAST(GET_JSON_OBJECT(raw_data, '$.mds_assessment.ot_tier') AS STRING) AS ot_tier,
  CAST(GET_JSON_OBJECT(raw_data, '$.mds_assessment.slp_tier') AS STRING) AS slp_tier,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.mds_assessment.section_i'), 'ARRAY<STRING>')) AS section_i_count,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.mds_assessment.section_o'), 'ARRAY<STRING>')) AS section_o_count,
  ARRAY_JOIN(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.mds_assessment.section_i'), 'ARRAY<STRING>'), ', ') AS section_i_codes,
  ARRAY_JOIN(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.mds_assessment.section_o'), 'ARRAY<STRING>'), ', ') AS section_o_services,
  CASE CAST(GET_JSON_OBJECT(raw_data, '$.mds_assessment.nursing_tier') AS STRING)
    WHEN 'ES3'
    THEN 5
    WHEN 'ES2'
    THEN 4
    WHEN 'HDE2'
    THEN 3
    WHEN 'HDE1'
    THEN 2
    ELSE 1
  END AS nursing_score, /* PDPM component scoring */
  CASE CAST(GET_JSON_OBJECT(raw_data, '$.mds_assessment.nta_tier') AS STRING)
    WHEN 'A'
    THEN 4
    WHEN 'B'
    THEN 3
    WHEN 'C'
    THEN 2
    ELSE 1
  END AS nta_score,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}