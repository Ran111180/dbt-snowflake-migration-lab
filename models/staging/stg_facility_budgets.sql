{# stg_facility_budgets: VARIANT financials, DIV0NULL, WIDTH_BUCKET #}
{{ config(materialized='view', tags=['staging', 'financial']) }}

SELECT
  raw_data:facility_id::STRING AS facility_id,
  raw_data:department::STRING AS department,
  raw_data:budget.allocated::FLOAT AS budget_allocated,
  raw_data:budget.spent::FLOAT AS budget_spent,
  raw_data:budget.remaining::FLOAT AS budget_remaining,
  DIV0NULL(raw_data:budget.spent::FLOAT, raw_data:budget.allocated::FLOAT) AS utilization_rate,
  DIV0NULL(raw_data:budget.remaining::FLOAT, raw_data:budget.allocated::FLOAT) AS remaining_pct,
  WIDTH_BUCKET(
    DIV0NULL(raw_data:budget.spent::FLOAT, raw_data:budget.allocated::FLOAT),
    0, 1.5, 5
  ) AS utilization_bucket,
  CASE
    WHEN DIV0NULL(raw_data:budget.spent::FLOAT, raw_data:budget.allocated::FLOAT) > 1.0 THEN 'OVER_BUDGET'
    WHEN DIV0NULL(raw_data:budget.spent::FLOAT, raw_data:budget.allocated::FLOAT) > 0.9 THEN 'AT_RISK'
    WHEN DIV0NULL(raw_data:budget.spent::FLOAT, raw_data:budget.allocated::FLOAT) > 0.7 THEN 'ON_TRACK'
    ELSE 'UNDER_UTILIZED'
  END AS budget_status,
  _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}
WHERE raw_data:budget IS NOT NULL
