{# stg_clinical_documents: PARSE_JSON, nested 3-level FLATTEN #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

WITH parsed AS (
  SELECT
    raw_data:patient_id::STRING AS patient_id,
    raw_data:encounter_id::STRING AS encounter_id,
    f.value AS document,
    f.index AS doc_idx
  FROM {{ source('landing', 'raw_encounters') }},
    LATERAL FLATTEN(input => raw_data:documents) f
),
sections AS (
  SELECT
    patient_id,
    encounter_id,
    document:doc_type::STRING AS document_type,
    document:title::STRING AS title,
    s.value:section_name::STRING AS section_name,
    s.value:content::STRING AS section_content,
    s.index AS section_idx
  FROM parsed,
    LATERAL FLATTEN(input => document:sections) s
)
SELECT
  patient_id,
  encounter_id,
  document_type,
  title,
  section_name,
  LEFT(section_content, 500) AS content_preview,
  LENGTH(section_content) AS content_length,
  section_idx + 1 AS section_number,
  IFF(CONTAINS(section_content, 'STAT'), TRUE, FALSE) AS is_urgent
FROM sections
WHERE section_content IS NOT NULL
