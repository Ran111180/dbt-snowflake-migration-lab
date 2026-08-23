{# int_diagnosis_pairs: Self-join for comorbidity analysis, HASH for dedup #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH dx AS (
    SELECT DISTINCT
        patient_id,
        icd10_code,
        diagnosis_description,
        severity
    FROM {{ ref('stg_diagnoses') }}
),

-- Generate all diagnosis pairs per patient
pairs AS (
    SELECT
        a.patient_id,
        a.icd10_code AS dx_1,
        b.icd10_code AS dx_2,
        a.diagnosis_description AS desc_1,
        b.diagnosis_description AS desc_2,
        a.severity AS severity_1,
        b.severity AS severity_2,
        HASH(LEAST(a.icd10_code, b.icd10_code), GREATEST(a.icd10_code, b.icd10_code)) AS pair_hash
    FROM dx a
    JOIN dx b
        ON a.patient_id = b.patient_id
        AND a.icd10_code < b.icd10_code
)

SELECT
    dx_1,
    dx_2,
    desc_1,
    desc_2,
    pair_hash,
    COUNT(DISTINCT patient_id) AS patient_count,
    RATIO_TO_REPORT(COUNT(DISTINCT patient_id)) OVER () AS prevalence_pct,
    ARRAY_AGG(DISTINCT patient_id) WITHIN GROUP (ORDER BY patient_id) AS patient_ids
FROM pairs
GROUP BY dx_1, dx_2, desc_1, desc_2, pair_hash
HAVING COUNT(DISTINCT patient_id) > 1
