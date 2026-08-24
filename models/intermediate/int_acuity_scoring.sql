{# int_acuity_scoring: CASE + QUALIFY + NTILE for patient acuity #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH scored AS (
  SELECT
    patient_id,
    full_name AS patient_name,
    age,
    diagnosis_count,
    medication_count,
    length_of_stay,
    -- Acuity score based on multiple factors
    CASE WHEN age > 85 THEN 4 WHEN age > 75 THEN 3 WHEN age > 65 THEN 2 ELSE 1 END
    + CASE WHEN diagnosis_count > 5 THEN 4 WHEN diagnosis_count > 3 THEN 3 WHEN diagnosis_count > 1 THEN 2 ELSE 1 END
    + CASE WHEN medication_count > 8 THEN 4 WHEN medication_count > 5 THEN 3 WHEN medication_count > 2 THEN 2 ELSE 1 END
    + CASE WHEN length_of_stay > 30 THEN 4 WHEN length_of_stay > 14 THEN 3 WHEN length_of_stay > 7 THEN 2 ELSE 1 END
    AS acuity_score
  FROM {{ ref('stg_patients') }}
)
SELECT
  patient_id,
  patient_name,
  age,
  diagnosis_count,
  medication_count,
  length_of_stay,
  acuity_score,
  NTILE(5) OVER (ORDER BY acuity_score DESC) AS acuity_quintile,
  PERCENT_RANK() OVER (ORDER BY acuity_score DESC) AS acuity_percentile,
  CASE
    WHEN NTILE(5) OVER (ORDER BY acuity_score DESC) = 1 THEN 'CRITICAL'
    WHEN NTILE(5) OVER (ORDER BY acuity_score DESC) = 2 THEN 'HIGH'
    WHEN NTILE(5) OVER (ORDER BY acuity_score DESC) = 3 THEN 'MODERATE'
    WHEN NTILE(5) OVER (ORDER BY acuity_score DESC) = 4 THEN 'LOW'
    ELSE 'MINIMAL'
  END AS acuity_category
FROM scored
QUALIFY
  ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY acuity_score DESC) = 1
