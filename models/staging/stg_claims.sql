{# stg_claims: VARIANT arrays, FLATTEN line items, ZEROIFNULL, NULLIF #}
{{ config(materialized='view', tags=['staging', 'billing']) }}

SELECT
    raw_data:claim_id::STRING AS claim_id,
    raw_data:patient_id::STRING AS patient_id,
    raw_data:encounter_id::STRING AS encounter_id,
    raw_data:payer::STRING AS payer_name,
    raw_data:claim_type::STRING AS claim_type,
    raw_data:status::STRING AS claim_status,
    TRY_CAST(raw_data:service_date::STRING AS DATE) AS service_date,
    TRY_CAST(raw_data:submit_date::STRING AS DATE) AS submit_date,
    TRY_CAST(raw_data:remit_date::STRING AS DATE) AS remit_date,
    raw_data:total_charges::FLOAT AS total_charges,
    raw_data:total_paid::FLOAT AS total_paid,
    ZEROIFNULL(raw_data:total_denied::FLOAT) AS total_denied,
    raw_data:total_charges::FLOAT - raw_data:total_paid::FLOAT - ZEROIFNULL(raw_data:total_denied::FLOAT) AS outstanding_amount,
    DIV0NULL(raw_data:total_paid::FLOAT, NULLIF(raw_data:total_charges::FLOAT, 0)) AS payment_ratio,
    DATEDIFF('day', TRY_CAST(raw_data:service_date::STRING AS DATE), TRY_CAST(raw_data:submit_date::STRING AS DATE)) AS days_to_submit,
    IFF(raw_data:remit_date IS NOT NULL,
        DATEDIFF('day', TRY_CAST(raw_data:submit_date::STRING AS DATE), TRY_CAST(raw_data:remit_date::STRING AS DATE)),
        NULL) AS days_to_payment,
    ARRAY_SIZE(raw_data:line_items) AS line_item_count,
    ARRAY_SIZE(raw_data:denial_reasons) AS denial_reason_count,
    IFF(raw_data:status::STRING = 'Denied', TRUE, FALSE) AS is_denied,
    IFF(raw_data:status::STRING IN ('Paid', 'Partially Paid'), TRUE, FALSE) AS is_paid,
    _ingested_at
FROM {{ source('landing', 'raw_claims') }}
