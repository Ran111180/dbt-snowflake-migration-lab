{# stg_staff_schedules: VARIANT shifts, DATEDIFF, DATEADD for scheduling #}
{{ config(materialized='view', tags=['staging', 'operations']) }}

SELECT
  raw_data:facility_id::STRING AS facility_id,
  raw_data:staff_id::STRING AS staff_id,
  raw_data:shift.start_time::TIMESTAMP AS shift_start,
  raw_data:shift.end_time::TIMESTAMP AS shift_end,
  DATEDIFF('hour', raw_data:shift.start_time::TIMESTAMP, raw_data:shift.end_time::TIMESTAMP) AS shift_hours,
  raw_data:shift.role::STRING AS shift_role,
  raw_data:shift.department::STRING AS department,
  DATEADD('hour', 12, raw_data:shift.start_time::TIMESTAMP) AS next_eligible_start,
  IFF(DATEDIFF('hour', raw_data:shift.start_time::TIMESTAMP, raw_data:shift.end_time::TIMESTAMP) > 12,
    'EXTENDED', 'STANDARD') AS shift_type,
  DAYOFWEEK(raw_data:shift.start_time::TIMESTAMP) AS day_of_week,
  IFF(DAYOFWEEK(raw_data:shift.start_time::TIMESTAMP) IN (0, 6), TRUE, FALSE) AS is_weekend,
  _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}
WHERE raw_data:shift IS NOT NULL
