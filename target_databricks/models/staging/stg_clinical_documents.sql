{# stg_clinical_documents: PARSE_JSON, nested 3-level FLATTEN #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

WITH parsed AS (
  SELECT
    CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
    CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING) AS encounter_id,
    f AS document
  FROM {{ source('landing', 'raw_encounters') }}
    LATERAL VIEW EXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.documents'), 'ARRAY<STRING>')) f_tbl AS f
), sections AS (
  SELECT
    patient_id,
    encounter_id,
    CAST(GET_JSON_OBJECT(document, '$.doc_type') AS STRING) AS document_type,
    CAST(GET_JSON_OBJECT(document, '$.title') AS STRING) AS title,
    CAST(GET_JSON_OBJECT(s, '$.section_name') AS STRING) AS section_name,
    CAST(GET_JSON_OBJECT(s, '$.content') AS STRING) AS section_content
  FROM parsed
    LATERAL VIEW EXPLODE(FROM_JSON(GET_JSON_OBJECT(document, '$.sections'), 'ARRAY<STRING>')) s_tbl AS s
)
SELECT
  patient_id,
  encounter_id,
  document_type,
  title,
  section_name,
  LEFT(section_content, 500) AS content_preview,
  LENGTH(section_content) AS content_length,
  IF(CONTAINS(section_content, 'STAT'), TRUE, FALSE) AS is_urgent
FROM sections
WHERE
  section_content IS NOT NULL