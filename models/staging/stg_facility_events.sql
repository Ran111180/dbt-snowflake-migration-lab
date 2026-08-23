{# stg_facility_events: VARIANT nested location, REGEXP, TO_TIMESTAMP, WIDTH_BUCKET #}
{{ config(materialized='view', tags=['staging', 'operations']) }}

SELECT
    raw_data:event_id::STRING AS event_id,
    raw_data:facility_id::STRING AS facility_id,
    raw_data:event_type::STRING AS event_type,
    TRY_CAST(raw_data:timestamp::STRING AS TIMESTAMP_NTZ) AS event_timestamp,
    raw_data:location.wing::STRING AS wing,
    raw_data:location.floor::INT AS floor_number,
    raw_data:location.room::INT AS room_number,
    raw_data:location.bed::STRING AS bed_id,
    CONCAT(raw_data:location.wing::STRING, '-', raw_data:location.floor::STRING, '-', raw_data:location.room::STRING, raw_data:location.bed::STRING) AS full_location,
    raw_data:patient_id::STRING AS patient_id,
    raw_data:staff_id::STRING AS staff_id,
    raw_data:severity::STRING AS severity,
    raw_data:sensor_data.value::FLOAT AS sensor_value,
    raw_data:sensor_data.unit::STRING AS sensor_unit,
    raw_data:sensor_data.threshold::FLOAT AS sensor_threshold,
    raw_data:sensor_data.is_breach::BOOLEAN AS is_threshold_breach,
    raw_data:resolved::BOOLEAN AS is_resolved,
    raw_data:resolution_time_minutes::INT AS resolution_minutes,
    -- Categorize response time
    WIDTH_BUCKET(ZEROIFNULL(raw_data:resolution_time_minutes::INT), 0, 120, 6) AS response_time_bucket,
    CASE WIDTH_BUCKET(ZEROIFNULL(raw_data:resolution_time_minutes::INT), 0, 120, 6)
        WHEN 1 THEN '0-20min' WHEN 2 THEN '20-40min' WHEN 3 THEN '40-60min'
        WHEN 4 THEN '60-80min' WHEN 5 THEN '80-100min' WHEN 6 THEN '100-120min'
        ELSE '120min+'
    END AS response_time_band,
    -- Extract tags
    ARRAY_SIZE(raw_data:tags) AS tag_count,
    _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}
