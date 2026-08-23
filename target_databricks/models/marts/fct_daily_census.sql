{# fct_daily_census: Incremental model with merge strategy #}
{{ config(
    materialized='incremental',
    unique_key='census_key',
    incremental_strategy='merge',
    tags=['marts', 'gold', 'daily']
) }}

WITH source AS (
  SELECT
    facility_id,
    admit_date AS census_date,
    COUNT(*) AS patient_count,
    COUNT_IF(is_current_resident) AS active_patients,
    AVG(length_of_stay) AS avg_los,
    AVG(age) AS avg_age,
    AVG(diagnosis_count) AS avg_complexity,
    COUNT_IF(age > 85) AS elderly_85_plus,
    COUNT_IF(length_of_stay > 60) AS long_stay_count
  FROM {{ ref('stg_patients') }}
  {% if is_incremental() %}
  WHERE
    _ingested_at > (
      SELECT
        MAX(_last_updated)
      FROM {{ this }}
    )
  {% endif %}
  GROUP BY
    facility_id,
    admit_date
)
SELECT
  MD5(
    CONCAT_WS(
      '|',
      COALESCE(CAST(facility_id AS STRING), '_null_'),
      COALESCE(CAST(census_date AS STRING), '_null_')
    )
  ) AS census_key,
  facility_id,
  census_date,
  patient_count,
  active_patients,
  ROUND(avg_los, 1) AS avg_length_of_stay,
  ROUND(avg_age, 0) AS avg_patient_age,
  ROUND(avg_complexity, 1) AS avg_diagnosis_count,
  elderly_85_plus,
  long_stay_count,
  CASE
    WHEN patient_count = 0 OR patient_count IS NULL
    THEN NULL
    ELSE CAST(active_patients AS DOUBLE) / CAST(patient_count AS DOUBLE)
  END AS occupancy_rate,
  CURRENT_TIMESTAMP() AS _last_updated
FROM source