{# stg_diagnoses: LATERAL FLATTEN on array, QUALIFY, ROW_NUMBER, TRY_CAST #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
    raw_data:patient_id::STRING AS patient_id,
    f.value:icd10::STRING AS icd10_code,
    f.value:description::STRING AS diagnosis_description,
    f.value:is_primary::BOOLEAN AS is_primary,
    TRY_CAST(f.value:onset::STRING AS DATE) AS onset_date,
    f.value:severity::STRING AS severity,
    f.index + 1 AS diagnosis_sequence,
    raw_data:admit_date::DATE AS admit_date,
    DATEDIFF('day', TRY_CAST(f.value:onset::STRING AS DATE), raw_data:admit_date::DATE) AS days_before_admission,
    IFF(f.value:is_primary::BOOLEAN, 'Primary', 'Secondary') AS diagnosis_type,
    _ingested_at
FROM {{ source('landing', 'raw_patients') }}
    , LATERAL FLATTEN(input => raw_data:diagnoses) AS f
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY raw_data:patient_id::STRING, f.value:icd10::STRING
    ORDER BY _ingested_at DESC
) = 1
