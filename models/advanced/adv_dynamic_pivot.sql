{# adv_dynamic_pivot: PIVOT with multiple value columns #}
{{ config(materialized='table', tags=['advanced', 'pivot']) }}

WITH monthly_metrics AS (
  SELECT
    facility_id,
    DATE_TRUNC('month', admit_date) AS month,
    COUNT(*) AS admissions,
    AVG(length_of_stay) AS avg_los,
    SUM(diagnosis_count) AS total_dx
  FROM {{ ref('stg_patients') }}
  WHERE admit_date >= DATEADD('month', -6, CURRENT_DATE())
  GROUP BY facility_id, DATE_TRUNC('month', admit_date)
),
ranked AS (
  SELECT
    facility_id,
    month,
    admissions,
    avg_los,
    RANK() OVER (PARTITION BY facility_id ORDER BY admissions DESC) AS busiest_month_rank,
    RANK() OVER (PARTITION BY facility_id ORDER BY avg_los DESC) AS highest_los_rank
  FROM monthly_metrics
)
SELECT *
FROM ranked
  PIVOT(MAX(admissions) FOR busiest_month_rank IN (1, 2, 3))
    AS p (facility_id, month, avg_los, highest_los_rank, rank_1_admissions, rank_2_admissions, rank_3_admissions)
ORDER BY facility_id
