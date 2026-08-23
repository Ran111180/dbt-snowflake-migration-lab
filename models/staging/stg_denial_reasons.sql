{# stg_denial_reasons: FLATTEN denial reasons array, REGEXP_REPLACE #}
{{ config(materialized='view', tags=['staging', 'billing']) }}

SELECT
    raw_data:claim_id::STRING AS claim_id,
    raw_data:patient_id::STRING AS patient_id,
    raw_data:payer::STRING AS payer_name,
    dr.value::STRING AS denial_reason_raw,
    REGEXP_REPLACE(dr.value::STRING, '[^a-zA-Z0-9 ]', '') AS denial_reason_clean,
    UPPER(TRIM(dr.value::STRING)) AS denial_reason_normalized,
    dr.index + 1 AS denial_sequence,
    raw_data:total_denied::FLOAT AS denied_amount,
    raw_data:total_charges::FLOAT AS total_charges,
    DIV0NULL(raw_data:total_denied::FLOAT, raw_data:total_charges::FLOAT) AS denial_rate,
    _ingested_at
FROM {{ source('landing', 'raw_claims') }}
    , LATERAL FLATTEN(input => raw_data:denial_reasons) AS dr
WHERE ARRAY_SIZE(raw_data:denial_reasons) > 0
