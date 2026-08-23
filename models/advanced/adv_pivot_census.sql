{# adv_pivot_census: PIVOT/UNPIVOT patterns #}
{{ config(materialized='table', tags=['advanced', 'pivot']) }}

WITH facility_events AS (
    SELECT
        facility_id,
        event_type,
        DATE_TRUNC('day', event_timestamp) AS event_date,
        COUNT(*) AS event_count
    FROM {{ ref('stg_facility_events') }}
    GROUP BY facility_id, event_type, DATE_TRUNC('day', event_timestamp)
),

-- PIVOT: Turn event types into columns
pivoted AS (
    SELECT *
    FROM facility_events
    PIVOT(SUM(event_count) FOR event_type IN (
        'bed_sensor', 'nurse_call', 'fall_alert', 'med_dispense', 
        'door_access', 'temp_alarm', 'elopement_risk', 'equipment_check'
    )) AS p (facility_id, event_date, bed_sensor, nurse_call, fall_alert, 
             med_dispense, door_access, temp_alarm, elopement_risk, equipment_check)
)

SELECT
    facility_id,
    event_date,
    NVL(bed_sensor, 0) AS bed_sensor_events,
    NVL(nurse_call, 0) AS nurse_call_events,
    NVL(fall_alert, 0) AS fall_alert_events,
    NVL(med_dispense, 0) AS med_dispense_events,
    NVL(door_access, 0) AS door_access_events,
    NVL(temp_alarm, 0) AS temp_alarm_events,
    NVL(elopement_risk, 0) AS elopement_risk_events,
    NVL(equipment_check, 0) AS equipment_check_events,
    NVL(bed_sensor, 0) + NVL(nurse_call, 0) + NVL(fall_alert, 0) + NVL(med_dispense, 0) 
        + NVL(door_access, 0) + NVL(temp_alarm, 0) + NVL(elopement_risk, 0) + NVL(equipment_check, 0) AS total_events,
    NVL(fall_alert, 0) + NVL(elopement_risk, 0) AS safety_events,
    NVL(nurse_call, 0) + NVL(bed_sensor, 0) AS care_events
FROM pivoted
ORDER BY facility_id, event_date
