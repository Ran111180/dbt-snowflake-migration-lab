{# dim_patients: SCD Type 2 dimension using dbt snapshot pattern #}
{{ config(
    materialized='table',
    tags=['marts', 'gold', 'dimension']
) }}

WITH current_data AS (
    SELECT
        patient_id,
        full_name,
        age,
        gender,
        race,
        preferred_language,
        city,
        state,
        zip_code,
        facility_id,
        is_current_resident,
        diagnosis_count,
        medication_count,
        ssn_hash,
        _ingested_at AS valid_from,
        {{ surrogate_key(['patient_id', 'full_name', 'facility_id', 'city', 'state']) }} AS row_hash
    FROM {{ ref('stg_patients') }}
)

SELECT
    {{ surrogate_key(['patient_id']) }} AS patient_key,
    patient_id,
    full_name,
    age,
    gender,
    race,
    preferred_language,
    city,
    state,
    zip_code,
    facility_id,
    is_current_resident,
    diagnosis_count,
    medication_count,
    ssn_hash,
    valid_from,
    CAST('{{ var("scd_valid_to") }}' AS DATE) AS valid_to,
    TRUE AS is_current,
    row_hash
FROM current_data
