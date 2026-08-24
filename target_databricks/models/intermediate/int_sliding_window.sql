{# int_sliding_window: Rolling window analytics on facility events #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH daily_events AS (
  SELECT
    facility_id,
    DATE_TRUNC('DAY', event_timestamp) AS event_date,
    COUNT(*) AS daily_event_count,
    COUNT_IF(severity = 'Critical') AS daily_critical,
    AVG(resolution_minutes) AS avg_resolution
  FROM {{ ref('stg_facility_events') }}
  GROUP BY
    facility_id,
    DATE_TRUNC('DAY', event_timestamp)
)
SELECT
  facility_id,
  event_date,
  daily_event_count,
  daily_critical,
  AVG(daily_event_count) OVER (
    PARTITION BY facility_id
    ORDER BY event_date ASC NULLS LAST
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) AS rolling_7d_avg_events,
  SUM(daily_critical) OVER (
    PARTITION BY facility_id
    ORDER BY event_date ASC NULLS LAST
    ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
  ) AS rolling_30d_critical_sum,
  daily_event_count - LAG(daily_event_count, 7) OVER (PARTITION BY facility_id ORDER BY event_date ASC NULLS LAST) AS week_over_week_change,
  SUM(daily_event_count) OVER (
    PARTITION BY facility_id
    ORDER BY event_date ASC NULLS LAST
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS cumulative_events,
  RANK() OVER (PARTITION BY facility_id ORDER BY daily_event_count DESC NULLS FIRST) AS busiest_day_rank,
  avg_resolution
FROM daily_events