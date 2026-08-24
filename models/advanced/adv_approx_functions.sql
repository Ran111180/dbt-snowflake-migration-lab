{# adv_approx_functions: APPROX_COUNT_DISTINCT, APPROX_PERCENTILE, HLL #}
{{ config(materialized='table', tags=['advanced', 'approximation']) }}

SELECT
  facility_id,
  DATE_TRUNC('month', admit_date) AS month,
  -- Exact vs approximate distinct counts
  COUNT(DISTINCT patient_id) AS exact_patient_count,
  APPROX_COUNT_DISTINCT(patient_id) AS approx_patient_count,
  -- Approximate percentiles (faster than exact on large datasets)
  APPROX_PERCENTILE(length_of_stay, 0.5) AS median_los,
  APPROX_PERCENTILE(length_of_stay, 0.25) AS p25_los,
  APPROX_PERCENTILE(length_of_stay, 0.75) AS p75_los,
  APPROX_PERCENTILE(length_of_stay, 0.95) AS p95_los,
  -- IQR calculation
  APPROX_PERCENTILE(length_of_stay, 0.75) - APPROX_PERCENTILE(length_of_stay, 0.25) AS iqr_los,
  -- Standard aggregates for comparison
  AVG(length_of_stay) AS avg_los,
  MIN(length_of_stay) AS min_los,
  MAX(length_of_stay) AS max_los,
  STDDEV(length_of_stay) AS stddev_los,
  COUNT(*) AS total_admissions
FROM {{ ref('stg_patients') }}
WHERE facility_id IS NOT NULL
GROUP BY facility_id, DATE_TRUNC('month', admit_date)
HAVING COUNT(*) >= 3
ORDER BY facility_id, month
