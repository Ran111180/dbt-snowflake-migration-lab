{# stg_facility_budgets: VARIANT financials, DIV0NULL, WIDTH_BUCKET #}
{{ config(materialized='view', tags=['staging', 'financial']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.facility_id') AS STRING) AS facility_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.department') AS STRING) AS department,
  CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) AS budget_allocated,
  CAST(GET_JSON_OBJECT(raw_data, '$.budget.spent') AS DOUBLE) AS budget_spent,
  CAST(GET_JSON_OBJECT(raw_data, '$.budget.remaining') AS DOUBLE) AS budget_remaining,
  IF(
    CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) = 0
    OR CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) IS NULL,
    0,
    CAST(GET_JSON_OBJECT(raw_data, '$.budget.spent') AS DOUBLE) / CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE)
  ) AS utilization_rate,
  IF(
    CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) = 0
    OR CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) IS NULL,
    0,
    CAST(GET_JSON_OBJECT(raw_data, '$.budget.remaining') AS DOUBLE) / CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE)
  ) AS remaining_pct,
  WIDTH_BUCKET(
    IF(
      CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) = 0
      OR CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) IS NULL,
      0,
      CAST(GET_JSON_OBJECT(raw_data, '$.budget.spent') AS DOUBLE) / CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE)
    ),
    0,
    1.5,
    5
  ) AS utilization_bucket,
  CASE
    WHEN IF(
      CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) = 0
      OR CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) IS NULL,
      0,
      CAST(GET_JSON_OBJECT(raw_data, '$.budget.spent') AS DOUBLE) / CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE)
    ) > 1.0
    THEN 'OVER_BUDGET'
    WHEN IF(
      CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) = 0
      OR CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) IS NULL,
      0,
      CAST(GET_JSON_OBJECT(raw_data, '$.budget.spent') AS DOUBLE) / CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE)
    ) > 0.9
    THEN 'AT_RISK'
    WHEN IF(
      CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) = 0
      OR CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE) IS NULL,
      0,
      CAST(GET_JSON_OBJECT(raw_data, '$.budget.spent') AS DOUBLE) / CAST(GET_JSON_OBJECT(raw_data, '$.budget.allocated') AS DOUBLE)
    ) > 0.7
    THEN 'ON_TRACK'
    ELSE 'UNDER_UTILIZED'
  END AS budget_status,
  _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}
WHERE
  GET_JSON_OBJECT(raw_data, '$.budget') IS NOT NULL