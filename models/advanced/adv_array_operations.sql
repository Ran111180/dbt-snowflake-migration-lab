{# adv_array_operations: Heavy ARRAY function usage #}
{{ config(materialized='table', tags=['advanced', 'arrays']) }}

WITH patient_dx_arrays AS (
    SELECT
        patient_id,
        ARRAY_AGG(DISTINCT icd10_code) WITHIN GROUP (ORDER BY icd10_code) AS all_dx_codes,
        ARRAY_AGG(DISTINCT diagnosis_description) WITHIN GROUP (ORDER BY diagnosis_description) AS all_dx_descriptions,
        ARRAY_AGG(DISTINCT severity) WITHIN GROUP (ORDER BY severity) AS severity_levels
    FROM {{ ref('stg_diagnoses') }}
    GROUP BY patient_id
),

patient_med_arrays AS (
    SELECT
        patient_id,
        ARRAY_AGG(DISTINCT medication_name) WITHIN GROUP (ORDER BY medication_name) AS all_medications,
        ARRAY_AGG(DISTINCT route) WITHIN GROUP (ORDER BY route) AS all_routes
    FROM {{ ref('stg_medications') }}
    GROUP BY patient_id
)

SELECT
    dx.patient_id,
    dx.all_dx_codes,
    dx.all_dx_descriptions,
    dx.severity_levels,
    meds.all_medications,
    meds.all_routes,
    -- Array operations
    ARRAY_SIZE(dx.all_dx_codes) AS unique_dx_count,
    ARRAY_SIZE(meds.all_medications) AS unique_med_count,
    ARRAY_CONTAINS('I10'::VARIANT, dx.all_dx_codes) AS has_hypertension,
    ARRAY_CONTAINS('E11.65'::VARIANT, dx.all_dx_codes) AS has_diabetes,
    ARRAY_CONTAINS('IV'::VARIANT, meds.all_routes) AS has_iv_meds,
    -- Array intersection simulation
    ARRAY_SIZE(ARRAY_INTERSECTION(dx.severity_levels, ARRAY_CONSTRUCT('Acute', 'Critical'::VARIANT))) AS acute_severity_count,
    -- Convert array to string
    ARRAY_TO_STRING(dx.all_dx_codes, ' | ') AS dx_codes_pipe_delimited,
    ARRAY_TO_STRING(meds.all_medications, ', ') AS medications_csv
FROM patient_dx_arrays dx
LEFT JOIN patient_med_arrays meds ON dx.patient_id = meds.patient_id
