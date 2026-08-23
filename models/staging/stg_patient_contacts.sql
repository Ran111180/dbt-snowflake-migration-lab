{# stg_patient_contacts: FLATTEN contacts array #}
{{ config(materialized='view', tags=['staging', 'patients']) }}

SELECT
    raw_data:patient_id::STRING AS patient_id,
    c.value:name::STRING AS contact_name,
    c.value:phone::STRING AS contact_phone,
    c.value:relationship::STRING AS relationship,
    REGEXP_REPLACE(c.value:phone::STRING, '[^0-9]', '') AS phone_digits_only,
    c.index + 1 AS contact_priority,
    _ingested_at
FROM {{ source('landing', 'raw_patients') }}
    , LATERAL FLATTEN(input => raw_data:contacts) AS c
