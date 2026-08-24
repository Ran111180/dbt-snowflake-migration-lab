{# adv_conditional_agg: GROUPING SETS + CUBE + ROLLUP combined #}
{{ config(materialized='table', tags=['advanced', 'aggregation']) }}

SELECT
  COALESCE(claim_type, 'ALL_TYPES') AS claim_type,
  COALESCE(payer_name, 'ALL_PAYERS') AS payer_name,
  COALESCE(claim_status, 'ALL_STATUSES') AS claim_status,
  COUNT(*) AS claim_count,
  SUM(total_charges) AS total_charges,
  SUM(total_paid) AS total_paid,
  AVG(total_charges) AS avg_charge,
  COUNT_IF(total_charges > 10000) AS high_value_claims,
  GROUPING(claim_type) AS is_type_rollup,
  GROUPING(payer_name) AS is_payer_rollup,
  GROUPING(claim_status) AS is_status_rollup,
  GROUPING_ID(claim_type, payer_name, claim_status) AS grouping_level
FROM {{ ref('stg_claims') }}
GROUP BY
  GROUPING SETS (
    (claim_type, payer_name, claim_status),
    (claim_type, payer_name),
    (
      claim_type
    ),
    (
      payer_name
    ),
    ()
  )
HAVING
  COUNT(*) > 0
ORDER BY 1 NULLS LAST,
  claim_type NULLS LAST,
  payer_name NULLS LAST