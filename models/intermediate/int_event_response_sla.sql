{# int_event_response_sla: SLA compliance with window functions #}
{{ config(materialized='table', tags=['intermediate', 'operations']) }}

SELECT
  facility_id,
  event_id,
  event_type,
  severity,
  event_timestamp,
  resolution_minutes,
  CASE severity
    WHEN 'Critical' THEN 30
    WHEN 'High' THEN 120
    WHEN 'Medium' THEN 480
    ELSE 1440
  END AS sla_target_minutes,
  IFF(resolution_minutes <= CASE severity WHEN 'Critical' THEN 30 WHEN 'High' THEN 120 WHEN 'Medium' THEN 480 ELSE 1440 END, TRUE, FALSE) AS sla_met,
  AVG(resolution_minutes) OVER (
    PARTITION BY facility_id, severity
    ORDER BY event_timestamp
    ROWS BETWEEN 9 PRECEDING AND CURRENT ROW
  ) AS rolling_10_avg_resolution,
  is_resolved
FROM {{ ref('stg_facility_events') }}
