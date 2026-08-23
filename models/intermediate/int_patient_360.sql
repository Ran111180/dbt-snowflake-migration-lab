{# int_patient_360: Multi-source join creating unified patient view #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH patients AS (
    SELECT * FROM {{ ref('stg_patients') }}
),

primary_dx AS (
    SELECT * FROM {{ ref('stg_primary_diagnosis') }}
),

mds AS (
    SELECT * FROM {{ ref('stg_mds_assessments') }}
),

insurance AS (
    SELECT 
        patient_id,
        payer_name AS primary_payer,
        plan_id AS primary_plan_id,
        months_enrolled
    FROM {{ ref('stg_insurance') }}
    WHERE is_primary = TRUE
),

vitals AS (
    SELECT * FROM {{ ref('stg_vitals') }}
)

SELECT
    p.patient_id,
    p.full_name,
    p.age,
    p.gender,
    p.race,
    p.facility_id,
    p.admit_date,
    p.discharge_date,
    p.is_current_resident,
    p.length_of_stay,
    p.diagnosis_count,
    p.medication_count,
    -- Primary diagnosis
    pdx.primary_icd10,
    pdx.primary_diagnosis_desc,
    pdx.severity AS primary_dx_severity,
    -- MDS scores
    mds.nursing_tier,
    mds.nta_tier,
    mds.pt_tier,
    mds.ot_tier,
    mds.nursing_score,
    mds.nta_score,
    mds.nursing_score + mds.nta_score AS combined_acuity_score,
    -- Insurance
    ins.primary_payer,
    ins.primary_plan_id,
    ins.months_enrolled,
    -- Vitals classification
    v.bp_classification,
    v.hr_classification,
    v.o2_classification,
    v.has_fever,
    -- Derived flags
    IFF(p.age > 85 AND p.diagnosis_count > 3 AND mds.nursing_score >= 4, TRUE, FALSE) AS is_high_acuity,
    IFF(p.length_of_stay > {{ var('los_long_stay') }}, TRUE, FALSE) AS is_long_stay,
    IFF(v.bp_classification IN ('Stage 2 HTN', 'Hypertensive Crisis') 
        OR v.o2_classification = 'Critical', TRUE, FALSE) AS has_vital_alert
FROM patients p
LEFT JOIN primary_dx pdx ON p.patient_id = pdx.patient_id
LEFT JOIN mds ON p.patient_id = mds.patient_id
LEFT JOIN insurance ins ON p.patient_id = ins.patient_id
LEFT JOIN vitals v ON p.patient_id = v.patient_id
