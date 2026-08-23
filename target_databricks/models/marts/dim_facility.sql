{# dim_facility: Reference dimension with seed join #}
{{ config(materialized='table', tags=['marts', 'gold', 'dimension']) }}

WITH facility_census AS (
  SELECT
    facility_id,
    COUNT(DISTINCT patient_id) AS total_patients,
    COUNT_IF(is_current_resident) AS active_patients,
    AVG(length_of_stay) AS avg_los,
    AVG(age) AS avg_age
  FROM {{ ref('stg_patients') }}
  GROUP BY
    facility_id
)
SELECT
  f.facility_id,
  f.facility_name,
  f.facility_type,
  f.state,
  f.bed_count,
  f.cms_rating,
  COALESCE(c.total_patients, 0) AS total_patients_served,
  COALESCE(c.active_patients, 0) AS current_census,
  CASE
    WHEN f.bed_count = 0 OR f.bed_count IS NULL
    THEN NULL
    ELSE CAST(c.active_patients AS DOUBLE) / CAST(f.bed_count AS DOUBLE)
  END AS occupancy_rate,
  ROUND(COALESCE(c.avg_los, 0), 1) AS avg_length_of_stay,
  ROUND(COALESCE(c.avg_age, 0), 0) AS avg_patient_age
FROM {{ ref('facility_reference') }} AS f
LEFT JOIN facility_census AS c
  ON f.facility_id = c.facility_id