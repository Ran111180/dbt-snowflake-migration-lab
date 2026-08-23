{# stg_encounter_diagnoses: FLATTEN diagnosis_codes array from encounters #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
    raw_data:encounter_id::STRING AS encounter_id,
    raw_data:patient_id::STRING AS patient_id,
    dx.value::STRING AS icd10_code,
    dx.index + 1 AS diagnosis_rank,
    IFF(dx.index = 0, TRUE, FALSE) AS is_primary,
    raw_data:encounter_type::STRING AS encounter_type,
    TRY_CAST(raw_data:admit_datetime::STRING AS DATE) AS encounter_date,
    _ingested_at
FROM {{ source('landing', 'raw_encounters') }}
    , LATERAL FLATTEN(input => raw_data:diagnosis_codes) AS dx
