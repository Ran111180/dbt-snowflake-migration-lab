{# stg_facility_tags: FLATTEN tags array from facility events #}
{{ config(materialized='view', tags=['staging', 'operations']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.event_id') AS STRING) AS event_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.facility_id') AS STRING) AS facility_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.event_type') AS STRING) AS event_type,
  CAST(t AS STRING) AS tag,
  t_pos + 1 AS tag_position,
  CAST(GET_JSON_OBJECT(raw_data, '$.severity') AS STRING) AS severity,
  IF(CAST(t AS STRING) = 'urgent', TRUE, FALSE) AS is_urgent,
  IF(CAST(t AS STRING) = 'escalated', TRUE, FALSE) AS is_escalated,
  TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.timestamp') AS STRING) AS TIMESTAMP) AS event_timestamp,
  _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.tags'), 'ARRAY<STRING>')) t_tbl AS t_pos, t