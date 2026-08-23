{# stg_patients: VARIANT path notation, type casting, IFF, DATEDIFF, ARRAY_SIZE #}
{{ config(materialized='view', tags=['staging', 'patients']) }}

WITH raw AS (
    SELECT raw_data, _ingested_at, _source_file, _batch_id
    FROM {{ source('landing', 'raw_patients') }}
)

SELECT
    raw_data:patient_id::STRING AS patient_id,
    raw_data:demographics.first_name::STRING AS first_name,
    raw_data:demographics.last_name::STRING AS last_name,
    CONCAT(raw_data:demographics.first_name::STRING, ' ', raw_data:demographics.last_name::STRING) AS full_name,
    raw_data:demographics.dob::DATE AS date_of_birth,
    DATEDIFF('year', raw_data:demographics.dob::DATE, CURRENT_DATE()) AS age,
    raw_data:demographics.gender::STRING AS gender,
    raw_data:demographics.race::STRING AS race,
    raw_data:demographics.language::STRING AS preferred_language,
    raw_data:demographics.marital_status::STRING AS marital_status,
    SHA2(raw_data:demographics.ssn::STRING, 256) AS ssn_hash,
    raw_data:address.street::STRING AS street,
    raw_data:address.city::STRING AS city,
    raw_data:address.state::STRING AS state,
    raw_data:address.zip::STRING AS zip_code,
    raw_data:facility_id::STRING AS facility_id,
    raw_data:admit_date::DATE AS admit_date,
    raw_data:discharge_date::DATE AS discharge_date,
    IFF(raw_data:discharge_date IS NULL, TRUE, FALSE) AS is_current_resident,
    DATEDIFF('day', raw_data:admit_date::DATE, COALESCE(raw_data:discharge_date::DATE, CURRENT_DATE())) AS length_of_stay,
    raw_data:vitals.bp_systolic::INT AS bp_systolic,
    raw_data:vitals.bp_diastolic::INT AS bp_diastolic,
    raw_data:vitals.heart_rate::INT AS heart_rate,
    raw_data:vitals.temperature::FLOAT AS temperature_f,
    raw_data:vitals.weight_lbs::FLOAT AS weight_lbs,
    raw_data:vitals.o2_saturation::INT AS o2_saturation,
    raw_data:vitals.pain_level::INT AS pain_level,
    ARRAY_SIZE(raw_data:diagnoses) AS diagnosis_count,
    ARRAY_SIZE(raw_data:medications) AS medication_count,
    ARRAY_SIZE(raw_data:lab_results) AS lab_result_count,
    raw_data:notes::STRING AS clinical_notes,
    _ingested_at,
    _source_file,
    _batch_id
FROM raw
