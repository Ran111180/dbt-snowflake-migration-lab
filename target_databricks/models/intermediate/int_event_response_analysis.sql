{# int_event_response_analysis: Window frames, FIRST_VALUE/LAST_VALUE, QUALIFY #}
{{ config(materialized='table', tags=['intermediate', 'operations']) }}

WITH events AS (
  SELECT
    event_id,
    facility_id,
    event_type,
    event_timestamp,
    severity,
    is_resolved,
    resolution_minutes,
    wing,
    floor_number,
    room_number,
    patient_id,
    staff_id
  FROM {{ ref('stg_facility_events') }}
), analyzed AS (
  SELECT
    *,
    DATEDIFF(
      MINUTE,
      LAG(event_timestamp) OVER (
        PARTITION BY facility_id, wing, floor_number
        ORDER BY event_timestamp ASC NULLS LAST
      ),
      event_timestamp
    ) AS minutes_since_last_event, /* Time since last event at same location */
    FIRST_VALUE(staff_id) OVER (
      PARTITION BY facility_id, wing, floor_number
      ORDER BY event_timestamp ASC NULLS LAST
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS first_responder, /* First responder for this location */
    LAST_VALUE(IF(is_resolved, event_id, NULL)) IGNORE NULLS OVER (
      PARTITION BY facility_id, wing
      ORDER BY event_timestamp ASC NULLS LAST
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) AS last_resolved_event_id, /* Last resolved event in this location */
    COUNT_IF(NOT is_resolved) OVER (
      PARTITION BY facility_id
      ORDER BY event_timestamp ASC NULLS LAST
      RANGE BETWEEN INTERVAL '1' HOUR PRECEDING AND CURRENT ROW
    ) AS unresolved_last_hour, /* Count of unresolved in last hour */
    AVG(resolution_minutes) OVER (
      PARTITION BY facility_id, event_type
      ORDER BY event_timestamp ASC NULLS LAST
      ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
    ) AS avg_response_last_5 /* Running average response time */
  FROM events
)
SELECT
  *
FROM analyzed
QUALIFY
  ROW_NUMBER() OVER (
    PARTITION BY facility_id, event_type, DATE_TRUNC('HOUR', event_timestamp)
    ORDER BY event_timestamp DESC NULLS FIRST
  ) <= 10