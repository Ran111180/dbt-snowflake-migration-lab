{# stg_facility_events: VARIANT nested location, REGEXP, TO_TIMESTAMP, WIDTH_BUCKET #}
{{ config(materialized='view', tags=['staging', 'operations']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.event_id') AS STRING) AS event_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.facility_id') AS STRING) AS facility_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.event_type') AS STRING) AS event_type,
  TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.timestamp') AS STRING) AS TIMESTAMP) AS event_timestamp,
  CAST(GET_JSON_OBJECT(raw_data, '$.location.wing') AS STRING) AS wing,
  CAST(GET_JSON_OBJECT(raw_data, '$.location.floor') AS DECIMAL(38, 0)) AS floor_number,
  CAST(GET_JSON_OBJECT(raw_data, '$.location.room') AS DECIMAL(38, 0)) AS room_number,
  CAST(GET_JSON_OBJECT(raw_data, '$.location.bed') AS STRING) AS bed_id,
  CONCAT(
    CAST(GET_JSON_OBJECT(raw_data, '$.location.wing') AS STRING),
    '-',
    CAST(GET_JSON_OBJECT(raw_data, '$.location.floor') AS STRING),
    '-',
    CAST(GET_JSON_OBJECT(raw_data, '$.location.room') AS STRING),
    CAST(GET_JSON_OBJECT(raw_data, '$.location.bed') AS STRING)
  ) AS full_location,
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.staff_id') AS STRING) AS staff_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.severity') AS STRING) AS severity,
  CAST(GET_JSON_OBJECT(raw_data, '$.sensor_data.value') AS DOUBLE) AS sensor_value,
  CAST(GET_JSON_OBJECT(raw_data, '$.sensor_data.unit') AS STRING) AS sensor_unit,
  CAST(GET_JSON_OBJECT(raw_data, '$.sensor_data.threshold') AS DOUBLE) AS sensor_threshold,
  CAST(GET_JSON_OBJECT(raw_data, '$.sensor_data.is_breach') AS BOOLEAN) AS is_threshold_breach,
  CAST(GET_JSON_OBJECT(raw_data, '$.resolved') AS BOOLEAN) AS is_resolved,
  CAST(GET_JSON_OBJECT(raw_data, '$.resolution_time_minutes') AS DECIMAL(38, 0)) AS resolution_minutes,
  WIDTH_BUCKET(
    IF(
      CAST(GET_JSON_OBJECT(raw_data, '$.resolution_time_minutes') AS DECIMAL(38, 0)) IS NULL,
      0,
      CAST(GET_JSON_OBJECT(raw_data, '$.resolution_time_minutes') AS DECIMAL(38, 0))
    ),
    0,
    120,
    6
  ) AS response_time_bucket, /* Categorize response time */
  CASE WIDTH_BUCKET(
      IF(
        CAST(GET_JSON_OBJECT(raw_data, '$.resolution_time_minutes') AS DECIMAL(38, 0)) IS NULL,
        0,
        CAST(GET_JSON_OBJECT(raw_data, '$.resolution_time_minutes') AS DECIMAL(38, 0))
      ),
      0,
      120,
      6
    )
    WHEN 1
    THEN '0-20min'
    WHEN 2
    THEN '20-40min'
    WHEN 3
    THEN '40-60min'
    WHEN 4
    THEN '60-80min'
    WHEN 5
    THEN '80-100min'
    WHEN 6
    THEN '100-120min'
    ELSE '120min+'
  END AS response_time_band,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.tags'), 'ARRAY<STRING>')) AS tag_count, /* Extract tags */
  _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}