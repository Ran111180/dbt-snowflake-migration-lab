{# stg_primary_diagnosis: FLATTEN + QUALIFY + FIRST_VALUE #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
    raw_data:patient_id::STRING AS patient_id,
    f.value:icd10::STRING AS primary_icd10,
    f.value:description::STRING AS primary_diagnosis_desc,
    f.value:severity::STRING AS severity,
    TRY_CAST(f.value:onset::STRING AS DATE) AS onset_date,
    FIRST_VALUE(f.value:icd10::STRING) OVER (
        PARTITION BY raw_data:patient_id::STRING
        ORDER BY IFF(f.value:is_primary::BOOLEAN, 0, 1), f.index
    ) AS confirmed_primary_dx,
    _ingested_at
FROM {{ source('landing', 'raw_patients') }}
    , LATERAL FLATTEN(input => raw_data:diagnoses) AS f
WHERE f.value:is_primary::BOOLEAN = TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY raw_data:patient_id::STRING
    ORDER BY _ingested_at DESC
) = 1
