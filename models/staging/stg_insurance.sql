{# stg_insurance: FLATTEN insurance array, OBJECT_KEYS pattern #}
{{ config(materialized='view', tags=['staging', 'patients']) }}

SELECT
    raw_data:patient_id::STRING AS patient_id,
    ins.value:payer::STRING AS payer_name,
    ins.value:plan_id::STRING AS plan_id,
    ins.value:group_id::STRING AS group_id,
    ins.value:type::STRING AS coverage_type,
    TRY_CAST(ins.value:effective_date::STRING AS DATE) AS effective_date,
    ins.index + 1 AS insurance_rank,
    IFF(ins.value:type::STRING = 'Primary', TRUE, FALSE) AS is_primary,
    DATEDIFF('month', TRY_CAST(ins.value:effective_date::STRING AS DATE), CURRENT_DATE()) AS months_enrolled,
    _ingested_at
FROM {{ source('landing', 'raw_patients') }}
    , LATERAL FLATTEN(input => raw_data:insurance) AS ins
