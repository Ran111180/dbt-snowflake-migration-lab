{# stg_provider_schedules: OBJECT_CONSTRUCT, OBJECT_KEYS, nested object access #}
{{ config(materialized='view', tags=['staging', 'providers']) }}

SELECT
  CAST(CAST(GET_JSON_OBJECT(raw_data, '$.provider_id') AS STRING) AS STRING) AS provider_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.name') AS STRING) AS provider_name,
  CAST(GET_JSON_OBJECT(raw_data, '$.specialty') AS STRING) AS specialty,
  STRUCT(
    CAST(GET_JSON_OBJECT(raw_data, '$.schedule.monday') AS STRING) AS monday,
    CAST(GET_JSON_OBJECT(raw_data, '$.schedule.tuesday') AS STRING) AS tuesday,
    CAST(GET_JSON_OBJECT(raw_data, '$.schedule.wednesday') AS STRING) AS wednesday
  ) AS weekly_schedule,
  SIZE(JSON_OBJECT_KEYS(GET_JSON_OBJECT(raw_data, '$.schedule'))) AS scheduled_days_count,
  CAST(GET_JSON_OBJECT(raw_data, '$.schedule.monday.start_time') AS STRING) AS monday_start,
  CAST(GET_JSON_OBJECT(raw_data, '$.schedule.monday.end_time') AS STRING) AS monday_end,
  DATEDIFF(
    HOUR,
    CAST(CAST(GET_JSON_OBJECT(raw_data, '$.schedule.monday.start_time') AS STRING) AS TIMESTAMP),
    CAST(CAST(GET_JSON_OBJECT(raw_data, '$.schedule.monday.end_time') AS STRING) AS TIMESTAMP)
  ) AS monday_hours,
  IF(CAST(GET_JSON_OBJECT(raw_data, '$.is_active') AS BOOLEAN), 'Active', 'Inactive') AS status,
  _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}
WHERE
  CAST(GET_JSON_OBJECT(raw_data, '$.record_type') AS STRING) = 'provider_schedule'