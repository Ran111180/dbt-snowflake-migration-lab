{# int_provider_panels: ARRAY_AGG + FLATTEN + COUNT per provider #}
{{ config(materialized='table', tags=['intermediate', 'providers']) }}

SELECT
  e.provider_npi AS provider_id,
  COUNT(DISTINCT e.patient_id) AS panel_size,
  ARRAY_AGG(DISTINCT e.patient_id) AS patient_list,
  COUNT(*) AS total_encounters,
  AVG(DATEDIFF('day', e.admit_datetime, COALESCE(e.discharge_datetime, CURRENT_TIMESTAMP()))) AS avg_los,
  COUNT_IF(e.encounter_type = 'Emergency') AS emergency_visits,
  0 AS readmissions,
  0.0 AS readmission_rate,
  MIN(e.admit_datetime) AS first_encounter,
  MAX(e.admit_datetime) AS last_encounter
FROM {{ ref('stg_encounters') }} e
WHERE e.provider_npi IS NOT NULL
GROUP BY e.provider_npi
HAVING COUNT(DISTINCT e.patient_id) >= 1
