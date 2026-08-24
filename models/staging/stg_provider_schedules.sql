{# stg_provider_schedules: OBJECT_CONSTRUCT, OBJECT_KEYS, nested object access #}
{{ config(materialized='view', tags=['staging', 'providers']) }}

SELECT
  CAST(raw_data:provider_id::STRING AS STRING) AS provider_id,
  raw_data:name::STRING AS provider_name,
  raw_data:specialty::STRING AS specialty,
  OBJECT_CONSTRUCT(
    'monday', raw_data:schedule.monday::STRING,
    'tuesday', raw_data:schedule.tuesday::STRING,
    'wednesday', raw_data:schedule.wednesday::STRING
  ) AS weekly_schedule,
  ARRAY_SIZE(OBJECT_KEYS(raw_data:schedule)) AS scheduled_days_count,
  raw_data:schedule.monday.start_time::STRING AS monday_start,
  raw_data:schedule.monday.end_time::STRING AS monday_end,
  DATEDIFF('hour',
    TRY_TO_TIME(raw_data:schedule.monday.start_time::STRING),
    TRY_TO_TIME(raw_data:schedule.monday.end_time::STRING)
  ) AS monday_hours,
  IFF(raw_data:is_active::BOOLEAN, 'Active', 'Inactive') AS status,
  _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}
WHERE raw_data:record_type::STRING = 'provider_schedule'
