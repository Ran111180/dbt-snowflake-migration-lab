{# stg_encounters: VARIANT nested objects, DATEADD, DATEDIFF, NVL2, COALESCE #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
    raw_data:encounter_id::STRING AS encounter_id,
    raw_data:patient_id::STRING AS patient_id,
    raw_data:facility_id::STRING AS facility_id,
    raw_data:encounter_type::STRING AS encounter_type,
    TRY_CAST(raw_data:admit_datetime::STRING AS TIMESTAMP_NTZ) AS admit_datetime,
    TRY_CAST(raw_data:discharge_datetime::STRING AS TIMESTAMP_NTZ) AS discharge_datetime,
    raw_data:attending_provider.npi::STRING AS provider_npi,
    raw_data:attending_provider.name::STRING AS provider_name,
    raw_data:attending_provider.specialty::STRING AS provider_specialty,
    raw_data:charges.room_and_board::FLOAT AS charge_room_board,
    raw_data:charges.pharmacy::FLOAT AS charge_pharmacy,
    raw_data:charges.supplies::FLOAT AS charge_supplies,
    raw_data:charges.professional::FLOAT AS charge_professional,
    raw_data:charges.total::FLOAT AS total_charges,
    raw_data:discharge_disposition::STRING AS discharge_disposition,
    raw_data:payer_id::STRING AS payer_id,
    raw_data:authorization.auth_number::STRING AS auth_number,
    raw_data:authorization.approved_days::INT AS approved_days,
    raw_data:authorization.used_days::INT AS used_days,
    raw_data:authorization.status::STRING AS auth_status,
    NVL2(raw_data:discharge_datetime, 
         DATEDIFF('hour', TRY_CAST(raw_data:admit_datetime::STRING AS TIMESTAMP_NTZ), TRY_CAST(raw_data:discharge_datetime::STRING AS TIMESTAMP_NTZ)),
         DATEDIFF('hour', TRY_CAST(raw_data:admit_datetime::STRING AS TIMESTAMP_NTZ), CURRENT_TIMESTAMP())
    ) AS total_hours,
    COALESCE(raw_data:authorization.approved_days::INT, 0) - COALESCE(raw_data:authorization.used_days::INT, 0) AS remaining_auth_days,
    IFF(raw_data:authorization.status::STRING = 'Denied', TRUE, FALSE) AS is_auth_denied,
    DATEADD('day', COALESCE(raw_data:authorization.approved_days::INT, 0), TRY_CAST(raw_data:admit_datetime::STRING AS TIMESTAMP_NTZ))::DATE AS auth_expiry_date,
    ARRAY_SIZE(raw_data:procedures) AS procedure_count,
    ARRAY_SIZE(raw_data:diagnosis_codes) AS diagnosis_code_count,
    _ingested_at
FROM {{ source('landing', 'raw_encounters') }}
