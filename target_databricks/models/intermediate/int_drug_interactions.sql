{# int_drug_interactions: ARRAY_INTERSECTION, ARRAY_EXCEPT, ARRAY_CONTAINS #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH patient_meds AS (
  SELECT
    patient_id,
    ARRAY_AGG(DISTINCT medication_name) AS current_medications,
    ARRAY_AGG(DISTINCT route) AS routes_used
  FROM {{ ref('stg_medications') }}
  GROUP BY
    patient_id
), known_interactions AS (
  SELECT
    patient_id,
    current_medications,
    ARRAY_INTERSECT(current_medications, ARRAY('Warfarin', 'Aspirin', 'Heparin', 'Enoxaparin')) AS blood_thinners, /* Check for known dangerous combinations */
    ARRAY_INTERSECT(current_medications, ARRAY('Metformin', 'Insulin', 'Glipizide')) AS diabetes_meds,
    ARRAY_INTERSECT(current_medications, ARRAY('Lisinopril', 'Losartan', 'Amlodipine', 'Metoprolol')) AS cardiac_meds
  FROM patient_meds
)
SELECT
  patient_id,
  current_medications,
  blood_thinners,
  diabetes_meds,
  cardiac_meds,
  SIZE(blood_thinners) AS blood_thinner_count,
  SIZE(diabetes_meds) AS diabetes_med_count,
  IF(SIZE(blood_thinners) > 1, TRUE, FALSE) AS dual_anticoag_risk,
  IF(
    ARRAY_CONTAINS(blood_thinners, 'Warfarin')
    AND ARRAY_CONTAINS(blood_thinners, 'Aspirin'),
    'HIGH',
    'LOW'
  ) AS bleeding_risk,
  SIZE(current_medications) AS total_med_count,
  IF(SIZE(current_medications) >= 5, 'Polypharmacy', 'Standard') AS polypharmacy_flag
FROM known_interactions