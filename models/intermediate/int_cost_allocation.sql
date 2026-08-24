{# int_cost_allocation: RATIO_TO_REPORT + GROUPING SETS #}
{{ config(materialized='table', tags=['intermediate', 'financial']) }}

SELECT
  COALESCE(claim_type, 'ALL') AS claim_type,
  COALESCE(payer_name, 'ALL') AS payer_name,
  COUNT(*) AS claim_count,
  SUM(total_charges) AS total_charges,
  SUM(total_paid) AS total_paid,
  SUM(total_charges) - SUM(total_paid) AS total_outstanding,
  RATIO_TO_REPORT(SUM(total_charges)) OVER () AS pct_of_total_charges,
  RATIO_TO_REPORT(SUM(total_paid)) OVER () AS pct_of_total_paid,
  AVG(total_charges) AS avg_charge_per_claim,
  GROUPING(claim_type) AS is_type_total,
  GROUPING(payer_name) AS is_payer_total
FROM {{ ref('stg_claims') }}
GROUP BY GROUPING SETS (
  (claim_type, payer_name),
  (claim_type),
  (payer_name),
  ()
)
