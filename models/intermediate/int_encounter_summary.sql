{# int_encounter_summary: Complex multi-join with encounter + procedures + claims #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH enc AS (
    SELECT * FROM {{ ref('stg_encounters') }}
),
proc AS (
    SELECT
        encounter_id,
        COUNT(*) AS procedure_count,
        SUM(charge_amount) AS total_procedure_charges,
        LISTAGG(DISTINCT procedure_category, ', ') WITHIN GROUP (ORDER BY procedure_category) AS procedure_categories,
        MAX(charge_amount) AS max_single_charge
    FROM {{ ref('stg_procedures') }}
    GROUP BY encounter_id
),
claims AS (
    SELECT
        encounter_id,
        COUNT(*) AS claim_count,
        SUM(total_charges) AS claimed_charges,
        SUM(total_paid) AS total_reimbursed,
        COUNT_IF(is_denied) AS denied_claims
    FROM {{ ref('stg_claims') }}
    GROUP BY encounter_id
)

SELECT
    enc.encounter_id,
    enc.patient_id,
    enc.facility_id,
    enc.encounter_type,
    enc.admit_datetime,
    enc.discharge_datetime,
    enc.total_hours,
    enc.provider_name,
    enc.provider_specialty,
    enc.discharge_disposition,
    enc.total_charges AS encounter_charges,
    NVL(proc.procedure_count, 0) AS procedure_count,
    NVL(proc.total_procedure_charges, 0) AS total_procedure_charges,
    proc.procedure_categories,
    NVL(claims.claim_count, 0) AS claim_count,
    NVL(claims.total_reimbursed, 0) AS total_reimbursed,
    NVL(claims.denied_claims, 0) AS denied_claims,
    {{ safe_divide('claims.total_reimbursed', 'enc.total_charges') }} AS reimbursement_rate,
    enc.auth_status,
    enc.remaining_auth_days,
    IFF(enc.remaining_auth_days < 3 AND enc.discharge_datetime IS NULL, TRUE, FALSE) AS needs_reauth
FROM enc
LEFT JOIN proc ON enc.encounter_id = proc.encounter_id
LEFT JOIN claims ON enc.encounter_id = claims.encounter_id
