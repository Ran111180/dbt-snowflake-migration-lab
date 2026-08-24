{# fct_quality_dashboard: Incremental + merge + QUALIFY #}
{{ config(
    materialized='incremental',
    unique_key='quality_key',
    incremental_strategy='merge',
    tags=['marts', 'quality']
) }}

WITH source AS (
  SELECT
    facility_id,
    DATE_TRUNC('week', _ingested_at) AS week_start,
    COUNT(DISTINCT patient_id) AS patients_seen,
    AVG(DATEDIFF('day', admit_datetime, COALESCE(discharge_datetime, CURRENT_TIMESTAMP()))) AS avg_los,
    0 AS readmissions,
    COUNT(*) AS total_encounters
  FROM {{ ref('stg_encounters') }}
  {% if is_incremental() %}
  WHERE _ingested_at > (SELECT MAX(_last_updated) FROM {{ this }})
  {% endif %}
  GROUP BY facility_id, DATE_TRUNC('week', _ingested_at)
)
SELECT
  MD5(CONCAT(facility_id, '|', CAST(week_start AS STRING))) AS quality_key,
  facility_id,
  week_start,
  patients_seen,
  ROUND(avg_los, 1) AS avg_length_of_stay,
  readmissions,
  total_encounters,
  DIV0NULL(readmissions, total_encounters) AS readmission_rate,
  CURRENT_TIMESTAMP() AS _last_updated
FROM source
QUALIFY
  ROW_NUMBER() OVER (PARTITION BY facility_id, week_start ORDER BY total_encounters DESC) = 1
