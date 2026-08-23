{# int_claims_revenue: Complex CTE chain, RATIO_TO_REPORT, conditional windows #}
{{ config(materialized='table', tags=['intermediate', 'billing']) }}

WITH claim_base AS (
  SELECT
    c.claim_id,
    c.patient_id,
    c.encounter_id,
    c.payer_name,
    c.claim_type,
    c.claim_status,
    c.total_charges,
    c.total_paid,
    c.total_denied,
    c.outstanding_amount,
    c.payment_ratio,
    c.days_to_submit,
    c.days_to_payment,
    c.is_denied,
    c.service_date
  FROM {{ ref('stg_claims') }} AS c
), payer_totals AS (
  SELECT
    payer_name,
    COUNT(*) AS total_claims,
    SUM(total_charges) AS payer_total_charges,
    SUM(total_paid) AS payer_total_paid,
    SUM(total_denied) AS payer_total_denied,
    AVG(payment_ratio) AS avg_payment_ratio,
    COUNT_IF(is_denied) AS denied_claims,
    MEDIAN(days_to_payment) AS median_days_to_pay
  FROM claim_base
  GROUP BY
    payer_name
), enriched AS (
  SELECT
    cb.*,
    pt.total_claims AS payer_claim_volume,
    pt.avg_payment_ratio AS payer_avg_ratio,
    pt.denied_claims AS payer_denied_count,
    (cb.total_charges) / SUM(cb.total_charges) OVER (PARTITION BY cb.payer_name) AS pct_of_payer_charges, /* Ratio to report within payer */
    RANK() OVER (PARTITION BY cb.payer_name ORDER BY cb.total_charges DESC NULLS FIRST) AS charge_rank_in_payer, /* Rank within payer */
    SUM(cb.total_paid) OVER (
      PARTITION BY cb.payer_name
      ORDER BY cb.service_date ASC NULLS LAST
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_paid_by_payer, /* Running total by service date */
    AVG(cb.total_charges) OVER (PARTITION BY cb.payer_name) AS payer_avg_charge, /* Is outlier (more than 2 std devs from mean) */
    STDDEV(cb.total_charges) OVER (PARTITION BY cb.payer_name) AS payer_stddev_charge
  FROM claim_base AS cb
  JOIN payer_totals AS pt
    ON cb.payer_name = pt.payer_name
)
SELECT
  *,
  IF(
    total_charges > payer_avg_charge + 2 * IF(payer_stddev_charge IS NULL, 0, payer_stddev_charge),
    TRUE,
    FALSE
  ) AS is_charge_outlier,
  CASE
    WHEN is_denied
    THEN 'Denied'
    WHEN payment_ratio >= 0.9
    THEN 'Fully Paid'
    WHEN payment_ratio >= 0.5
    THEN 'Partially Paid'
    WHEN payment_ratio > 0
    THEN 'Underpaid'
    ELSE 'Unpaid'
  END AS payment_category
FROM enriched