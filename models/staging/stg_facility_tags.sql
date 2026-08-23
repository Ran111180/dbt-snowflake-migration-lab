{# stg_facility_tags: FLATTEN tags array from facility events #}
{{ config(materialized='view', tags=['staging', 'operations']) }}

SELECT
    raw_data:event_id::STRING AS event_id,
    raw_data:facility_id::STRING AS facility_id,
    raw_data:event_type::STRING AS event_type,
    t.value::STRING AS tag,
    t.index + 1 AS tag_position,
    raw_data:severity::STRING AS severity,
    IFF(t.value::STRING = 'urgent', TRUE, FALSE) AS is_urgent,
    IFF(t.value::STRING = 'escalated', TRUE, FALSE) AS is_escalated,
    TRY_CAST(raw_data:timestamp::STRING AS TIMESTAMP_NTZ) AS event_timestamp,
    _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}
    , LATERAL FLATTEN(input => raw_data:tags) AS t
