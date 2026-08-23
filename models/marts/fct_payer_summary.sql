{# fct_payer_summary: Aggregated fact by payer, GROUPING SETS pattern #}
{{ config(materialized='table', tags=['marts', 'gold', 'billing']) }}

SELECT
    COALESCE(payer_name, 'ALL PAYERS') AS payer_name,
    COALESCE(claim_type, 'ALL TYPES') AS claim_type,
    COUNT(*) AS total_claims,
    SUM(total_charges) AS sum_charges,
    SUM(total_paid) AS sum_paid,
    SUM(total_denied) AS sum_denied,
    AVG(payment_ratio) AS avg_payment_ratio,
    COUNT_IF(is_denied) AS denied_count,
    {{ safe_divide('COUNT_IF(is_denied)', 'COUNT(*)') }} AS denial_rate,
    MEDIAN(days_to_payment) AS median_days_to_pay,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_charges) AS p90_charge,
    GROUPING(payer_name) AS is_payer_total,
    GROUPING(claim_type) AS is_type_total
FROM {{ ref('stg_claims') }}
GROUP BY GROUPING SETS (
    (payer_name, claim_type),
    (payer_name),
    ()
)
