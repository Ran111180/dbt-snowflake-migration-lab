{# stg_care_plans: VARIANT array of objects, LISTAGG #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  raw_data:encounter_id::STRING AS encounter_id,
  f.value:goal::STRING AS care_goal,
  f.value:intervention::STRING AS intervention,
  f.value:status::STRING AS goal_status,
  f.value:priority::NUMBER AS priority_rank,
  TRY_TO_DATE(f.value:target_date::STRING) AS target_date,
  f.index + 1 AS goal_sequence,
  LISTAGG(f.value:intervention::STRING, '; ') WITHIN GROUP (ORDER BY f.value:priority::NUMBER)
    OVER (PARTITION BY raw_data:patient_id::STRING) AS all_interventions,
  _ingested_at
FROM {{ source('landing', 'raw_encounters') }},
  LATERAL FLATTEN(input => raw_data:care_plan) f
WHERE f.value:goal IS NOT NULL
