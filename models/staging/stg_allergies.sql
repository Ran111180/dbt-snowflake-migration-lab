{# stg_allergies: VARIANT FLATTEN array, QUALIFY dedup #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  f.value:allergen::STRING AS allergen,
  f.value:reaction::STRING AS reaction_type,
  f.value:severity::STRING AS severity,
  TRY_TO_DATE(f.value:reported_date::STRING) AS reported_date,
  f.index + 1 AS allergy_seq,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }},
  LATERAL FLATTEN(input => raw_data:allergies) f
QUALIFY
  ROW_NUMBER() OVER (
    PARTITION BY raw_data:patient_id::STRING, f.value:allergen::STRING
    ORDER BY _ingested_at DESC
  ) = 1
