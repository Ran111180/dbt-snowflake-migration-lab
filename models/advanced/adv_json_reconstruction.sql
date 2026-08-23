{# adv_json_reconstruction: OBJECT_CONSTRUCT, ARRAY_CONSTRUCT, complex JSON building #}
{{ config(materialized='table', tags=['advanced', 'json']) }}

WITH patient_data AS (
    SELECT
        p.patient_id,
        p.full_name,
        p.age,
        p.gender,
        p.facility_id,
        p.diagnosis_count,
        p.medication_count
    FROM {{ ref('stg_patients') }} p
),

patient_diagnoses AS (
    SELECT
        patient_id,
        ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'code', icd10_code,
                'description', diagnosis_description,
                'is_primary', is_primary,
                'severity', severity
            )
        ) WITHIN GROUP (ORDER BY diagnosis_sequence) AS diagnoses_array
    FROM {{ ref('stg_diagnoses') }}
    GROUP BY patient_id
),

patient_meds AS (
    SELECT
        patient_id,
        ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'name', medication_name,
                'dose', dose,
                'route', route,
                'frequency', frequency,
                'is_injectable', is_injectable
            )
        ) WITHIN GROUP (ORDER BY medication_sequence) AS medications_array
    FROM {{ ref('stg_medications') }}
    GROUP BY patient_id
)

SELECT
    pd.patient_id,
    OBJECT_CONSTRUCT(
        'patient_id', pd.patient_id,
        'demographics', OBJECT_CONSTRUCT(
            'name', pd.full_name,
            'age', pd.age,
            'gender', pd.gender,
            'facility', pd.facility_id
        ),
        'clinical', OBJECT_CONSTRUCT(
            'diagnosis_count', pd.diagnosis_count,
            'medication_count', pd.medication_count,
            'diagnoses', NVL(dx.diagnoses_array, ARRAY_CONSTRUCT()),
            'medications', NVL(meds.medications_array, ARRAY_CONSTRUCT())
        ),
        'metadata', OBJECT_CONSTRUCT(
            'generated_at', CURRENT_TIMESTAMP()::STRING,
            'version', '2.0'
        )
    ) AS patient_fhir_bundle,
    ARRAY_SIZE(NVL(dx.diagnoses_array, ARRAY_CONSTRUCT())) AS actual_dx_count,
    ARRAY_SIZE(NVL(meds.medications_array, ARRAY_CONSTRUCT())) AS actual_med_count
FROM patient_data pd
LEFT JOIN patient_diagnoses dx ON pd.patient_id = dx.patient_id
LEFT JOIN patient_meds meds ON pd.patient_id = meds.patient_id
