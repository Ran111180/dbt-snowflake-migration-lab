{# stg_claim_lines: FLATTEN claim line items, window SUM, conditional aggregation #}
{{ config(materialized='view', tags=['staging', 'billing']) }}

SELECT
    raw_data:claim_id::STRING AS claim_id,
    raw_data:patient_id::STRING AS patient_id,
    raw_data:payer::STRING AS payer_name,
    li.value:line_no::INT AS line_number,
    li.value:cpt::STRING AS cpt_code,
    li.value:units::INT AS units,
    li.value:charge::FLOAT AS line_charge,
    li.value:paid::FLOAT AS line_paid,
    li.value:adjustment::FLOAT AS line_adjustment,
    li.value:denial_code::STRING AS denial_code,
    IFF(li.value:denial_code IS NOT NULL, TRUE, FALSE) AS is_line_denied,
    -- Running total within claim
    SUM(li.value:charge::FLOAT) OVER (
        PARTITION BY raw_data:claim_id::STRING
        ORDER BY li.value:line_no::INT
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_charge_total,
    -- Percent of claim total
    DIV0NULL(li.value:charge::FLOAT, raw_data:total_charges::FLOAT) AS pct_of_total,
    _ingested_at
FROM {{ source('landing', 'raw_claims') }}
    , LATERAL FLATTEN(input => raw_data:line_items) AS li
