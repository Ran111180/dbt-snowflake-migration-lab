{# int_los_distribution: WIDTH_BUCKET, GENERATOR for histogram, conditional agg #}
{{ config(materialized='table', tags=['intermediate', 'operations']) }}

WITH patients AS (
  SELECT
    patient_id,
    facility_id,
    length_of_stay,
    age,
    diagnosis_count,
    is_current_resident
  FROM {{ ref('stg_patients') }}
  WHERE
    length_of_stay > 0
), buckets /* Generate bucket boundaries using GENERATOR */ AS (
  SELECT
    id * 7 AS bucket_start,
    (
      id + 1
    ) * 7 AS bucket_end
  FROM (SELECT EXPLODE(SEQUENCE(0, 14)) AS id)
), bucketed AS (
  SELECT
    p.*,
    WIDTH_BUCKET(length_of_stay, 0, 105, 15) AS los_bucket,
    CASE
      WHEN length_of_stay <= 7
      THEN 'Short Stay (0-7d)'
      WHEN length_of_stay <= 20
      THEN 'Standard (8-20d)'
      WHEN length_of_stay <= 60
      THEN 'Long Stay (21-60d)'
      ELSE 'Extended (60d+)'
    END AS los_category
  FROM patients AS p
)
SELECT
  facility_id,
  los_category,
  los_bucket,
  COUNT(*) AS patient_count,
  AVG(length_of_stay) AS avg_los_in_bucket,
  MIN(length_of_stay) AS min_los,
  MAX(length_of_stay) AS max_los,
  AVG(age) AS avg_age_in_bucket,
  AVG(diagnosis_count) AS avg_dx_count,
  COUNT_IF(is_current_resident) AS still_active,
  (COUNT(*)) / SUM(COUNT(*)) OVER (PARTITION BY facility_id) AS pct_of_facility
FROM bucketed
GROUP BY
  facility_id,
  los_category,
  los_bucket
ORDER BY
  facility_id NULLS LAST,
  los_bucket NULLS LAST