{# int_payer_performance: Complex aggregation, CONDITIONAL_CHANGE_EVENT pattern #}
{{ config(materialized='table', tags=['intermediate', 'billing']) }}

WITH claims AS (
  SELECT
    *
  FROM {{ ref('stg_claims') }}
), payer_metrics AS (
  SELECT
    payer_name,
    claim_type,
    COUNT(*) AS total_claims,
    SUM(total_charges) AS sum_charges,
    SUM(total_paid) AS sum_paid,
    SUM(total_denied) AS sum_denied,
    SUM(outstanding_amount) AS sum_outstanding,
    AVG(payment_ratio) AS avg_payment_ratio,
    MEDIAN(days_to_submit) AS median_days_to_submit,
    MEDIAN(days_to_payment) AS median_days_to_pay,
    COUNT_IF(is_denied) AS denied_count,
    COUNT_IF(is_paid) AS paid_count,
    IF(COUNT(*) = 0 OR COUNT(*) IS NULL, 0, COUNT_IF(is_denied) / COUNT(*)) AS denial_rate,
    STDDEV(total_charges) AS charge_stddev, /* Standard deviation of charges */
    VARIANCE(total_charges) AS charge_variance,
    APPROX_PERCENTILE(total_charges, 0.25) AS p25_charge,
    APPROX_PERCENTILE(total_charges, 0.50) AS p50_charge,
    APPROX_PERCENTILE(total_charges, 0.75) AS p75_charge,
    APPROX_PERCENTILE(total_charges, 0.95) AS p95_charge
  FROM claims
  GROUP BY
    payer_name,
    claim_type
)
SELECT
  *,
  p75_charge - p25_charge AS iqr,
  p25_charge - 1.5 * (
    p75_charge - p25_charge
  ) AS outlier_low_threshold,
  p75_charge + 1.5 * (
    p75_charge - p25_charge
  ) AS outlier_high_threshold,
  RANK() OVER (ORDER BY sum_charges DESC NULLS FIRST) AS charge_rank,
  RANK() OVER (ORDER BY denial_rate ASC NULLS LAST) AS denial_rank,
  CASE
    WHEN denial_rate > 0.20
    THEN 'Poor'
    WHEN denial_rate > 0.10
    THEN 'Below Average'
    WHEN denial_rate > 0.05
    THEN 'Average'
    ELSE 'Excellent'
  END AS payer_grade
FROM payer_metrics