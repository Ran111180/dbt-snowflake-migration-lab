{# adv_pivot_census: PIVOT/UNPIVOT patterns #}
{{ config(materialized='table', tags=['advanced', 'pivot']) }}

WITH facility_events AS (
  SELECT
    facility_id,
    event_type,
    DATE_TRUNC('DAY', event_timestamp) AS event_date,
    COUNT(*) AS event_count
  FROM {{ ref('stg_facility_events') }}
  GROUP BY
    facility_id,
    event_type,
    DATE_TRUNC('DAY', event_timestamp)
), pivoted /* PIVOT: Turn event types into columns */ AS (
  SELECT
    *
  FROM (
    SELECT
      *
    FROM facility_events
    PIVOT(SUM(event_count) FOR 
      event_type IN (
        'bed_sensor',
        'nurse_call',
        'fall_alert',
        'med_dispense',
        'door_access',
        'temp_alarm',
        'elopement_risk',
        'equipment_check'
      )
    )
  ) AS p(facility_id, event_date, bed_sensor, nurse_call, fall_alert, med_dispense, door_access, temp_alarm, elopement_risk, equipment_check)
)
SELECT
  facility_id,
  event_date,
  COALESCE(bed_sensor, 0) AS bed_sensor_events,
  COALESCE(nurse_call, 0) AS nurse_call_events,
  COALESCE(fall_alert, 0) AS fall_alert_events,
  COALESCE(med_dispense, 0) AS med_dispense_events,
  COALESCE(door_access, 0) AS door_access_events,
  COALESCE(temp_alarm, 0) AS temp_alarm_events,
  COALESCE(elopement_risk, 0) AS elopement_risk_events,
  COALESCE(equipment_check, 0) AS equipment_check_events,
  COALESCE(bed_sensor, 0) + COALESCE(nurse_call, 0) + COALESCE(fall_alert, 0) + COALESCE(med_dispense, 0) + COALESCE(door_access, 0) + COALESCE(temp_alarm, 0) + COALESCE(elopement_risk, 0) + COALESCE(equipment_check, 0) AS total_events,
  COALESCE(fall_alert, 0) + COALESCE(elopement_risk, 0) AS safety_events,
  COALESCE(nurse_call, 0) + COALESCE(bed_sensor, 0) AS care_events
FROM pivoted
ORDER BY
  facility_id NULLS LAST,
  event_date NULLS LAST