{# stg_staff_schedules: VARIANT shifts, DATEDIFF, DATEADD for scheduling #}
{{ config(materialized='view', tags=['staging', 'operations']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.facility_id') AS STRING) AS facility_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.staff_id') AS STRING) AS staff_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.shift.start_time') AS TIMESTAMP) AS shift_start,
  CAST(GET_JSON_OBJECT(raw_data, '$.shift.end_time') AS TIMESTAMP) AS shift_end,
  DATEDIFF(
    HOUR,
    CAST(GET_JSON_OBJECT(raw_data, '$.shift.start_time') AS TIMESTAMP),
    CAST(GET_JSON_OBJECT(raw_data, '$.shift.end_time') AS TIMESTAMP)
  ) AS shift_hours,
  CAST(GET_JSON_OBJECT(raw_data, '$.shift.role') AS STRING) AS shift_role,
  CAST(GET_JSON_OBJECT(raw_data, '$.shift.department') AS STRING) AS department,
  DATEADD(HOUR, 12, CAST(GET_JSON_OBJECT(raw_data, '$.shift.start_time') AS TIMESTAMP)) AS next_eligible_start,
  IF(
    DATEDIFF(
      HOUR,
      CAST(GET_JSON_OBJECT(raw_data, '$.shift.start_time') AS TIMESTAMP),
      CAST(GET_JSON_OBJECT(raw_data, '$.shift.end_time') AS TIMESTAMP)
    ) > 12,
    'EXTENDED',
    'STANDARD'
  ) AS shift_type,
  DAYOFWEEK(CAST(GET_JSON_OBJECT(raw_data, '$.shift.start_time') AS TIMESTAMP)) AS day_of_week,
  IF(DAYOFWEEK(CAST(GET_JSON_OBJECT(raw_data, '$.shift.start_time') AS TIMESTAMP)) IN (0, 6), TRUE, FALSE) AS is_weekend,
  _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}
WHERE
  GET_JSON_OBJECT(raw_data, '$.shift') IS NOT NULL