{# adv_array_operations: Heavy ARRAY function usage #}
{{ config(materialized='table', tags=['advanced', 'arrays']) }}

WITH patient_dx_arrays AS (
  SELECT
    patient_id,
    SORT_ARRAY(ARRAY_AGG(DISTINCT icd10_code)) AS all_dx_codes,
    SORT_ARRAY(ARRAY_AGG(DISTINCT diagnosis_description)) AS all_dx_descriptions,
    SORT_ARRAY(ARRAY_AGG(DISTINCT severity)) AS severity_levels
  FROM {{ ref('stg_diagnoses') }}
  GROUP BY
    patient_id
), patient_med_arrays AS (
  SELECT
    patient_id,
    SORT_ARRAY(ARRAY_AGG(DISTINCT medication_name)) AS all_medications,
    SORT_ARRAY(ARRAY_AGG(DISTINCT route)) AS all_routes
  FROM {{ ref('stg_medications') }}
  GROUP BY
    patient_id
)
SELECT
  dx.patient_id,
  dx.all_dx_codes,
  dx.all_dx_descriptions,
  dx.severity_levels,
  meds.all_medications,
  meds.all_routes,
  SIZE(dx.all_dx_codes) AS unique_dx_count, /* Array operations */
  SIZE(meds.all_medications) AS unique_med_count,
  ARRAY_CONTAINS(dx.all_dx_codes, 'I10') AS has_hypertension,
  ARRAY_CONTAINS(dx.all_dx_codes, 'E11.65') AS has_diabetes,
  ARRAY_CONTAINS(meds.all_routes, 'IV') AS has_iv_meds,
  SIZE(ARRAY_INTERSECT(dx.severity_levels, ARRAY('Acute', 'Critical'))) AS acute_severity_count, /* Array intersection simulation */
  ARRAY_JOIN(dx.all_dx_codes, ' | ') AS dx_codes_pipe_delimited, /* Convert array to string */
  ARRAY_JOIN(meds.all_medications, ', ') AS medications_csv
FROM patient_dx_arrays AS dx
LEFT JOIN patient_med_arrays AS meds
  ON dx.patient_id = meds.patient_id