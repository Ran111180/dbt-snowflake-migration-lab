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
),

analyzed AS (
    SELECT
        *,
        -- Time since last event at same location
        DATEDIFF('minute', 
            LAG(event_timestamp) OVER (PARTITION BY facility_id, wing, floor_number ORDER BY event_timestamp),
            event_timestamp
        ) AS minutes_since_last_event,
        -- First responder for this location
        FIRST_VALUE(staff_id) OVER (
            PARTITION BY facility_id, wing, floor_number
            ORDER BY event_timestamp
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS first_responder,
        -- Last resolved event in this location
        LAST_VALUE(IFF(is_resolved, event_id, NULL) IGNORE NULLS) OVER (
            PARTITION BY facility_id, wing
            ORDER BY event_timestamp
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS last_resolved_event_id,
        -- Count of unresolved in last hour
        COUNT_IF(NOT is_resolved) OVER (
            PARTITION BY facility_id
            ORDER BY event_timestamp
            RANGE BETWEEN INTERVAL '1 HOUR' PRECEDING AND CURRENT ROW
        ) AS unresolved_last_hour,
        -- Running average response time
        AVG(resolution_minutes) OVER (
            PARTITION BY facility_id, event_type
            ORDER BY event_timestamp
            ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
        ) AS avg_response_last_5
    FROM events
)

SELECT * FROM analyzed
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY facility_id, event_type, DATE_TRUNC('hour', event_timestamp)
    ORDER BY event_timestamp DESC
) <= 10
