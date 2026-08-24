{# fct_staffing_metrics: PIVOT + derived metrics #}
{{ config(materialized='table', tags=['marts', 'operations']) }}

WITH daily_staff AS (
  SELECT
    facility_id,
    DATE_TRUNC('day', event_timestamp) AS event_date,
    severity,
    COUNT(*) AS event_count
  FROM {{ ref('stg_facility_events') }}
  GROUP BY facility_id, DATE_TRUNC('day', event_timestamp), severity
)
SELECT *
FROM daily_staff
  PIVOT(SUM(event_count) FOR severity IN ('Critical', 'High', 'Medium', 'Low'))
    AS p (facility_id, event_date, critical_events, high_events, medium_events, low_events)
ORDER BY facility_id, event_date
