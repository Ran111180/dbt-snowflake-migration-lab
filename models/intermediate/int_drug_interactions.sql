{# int_drug_interactions: ARRAY_INTERSECTION, ARRAY_EXCEPT, ARRAY_CONTAINS #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH patient_meds AS (
  SELECT
    patient_id,
    ARRAY_AGG(DISTINCT medication_name) AS current_medications,
    ARRAY_AGG(DISTINCT route) AS routes_used
  FROM {{ ref('stg_medications') }}
  GROUP BY patient_id
),
known_interactions AS (
  SELECT
    patient_id,
    current_medications,
    -- Check for known dangerous combinations
    ARRAY_INTERSECTION(
      current_medications,
      ARRAY_CONSTRUCT('Warfarin', 'Aspirin', 'Heparin', 'Enoxaparin')
    ) AS blood_thinners,
    ARRAY_INTERSECTION(
      current_medications,
      ARRAY_CONSTRUCT('Metformin', 'Insulin', 'Glipizide')
    ) AS diabetes_meds,
    ARRAY_INTERSECTION(
      current_medications,
      ARRAY_CONSTRUCT('Lisinopril', 'Losartan', 'Amlodipine', 'Metoprolol')
    ) AS cardiac_meds
  FROM patient_meds
)
SELECT
  patient_id,
  current_medications,
  blood_thinners,
  diabetes_meds,
  cardiac_meds,
  ARRAY_SIZE(blood_thinners) AS blood_thinner_count,
  ARRAY_SIZE(diabetes_meds) AS diabetes_med_count,
  IFF(ARRAY_SIZE(blood_thinners) > 1, TRUE, FALSE) AS dual_anticoag_risk,
  IFF(
    ARRAY_CONTAINS('Warfarin'::VARIANT, blood_thinners)
    AND ARRAY_CONTAINS('Aspirin'::VARIANT, blood_thinners),
    'HIGH', 'LOW'
  ) AS bleeding_risk,
  ARRAY_SIZE(current_medications) AS total_med_count,
  IFF(ARRAY_SIZE(current_medications) >= 5, 'Polypharmacy', 'Standard') AS polypharmacy_flag
FROM known_interactions
