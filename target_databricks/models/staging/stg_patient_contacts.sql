{# stg_patient_contacts: FLATTEN contacts array #}
{{ config(materialized='view', tags=['staging', 'patients']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(c, '$.name') AS STRING) AS contact_name,
  CAST(GET_JSON_OBJECT(c, '$.phone') AS STRING) AS contact_phone,
  CAST(GET_JSON_OBJECT(c, '$.relationship') AS STRING) AS relationship,
  REGEXP_REPLACE(CAST(GET_JSON_OBJECT(c, '$.phone') AS STRING), '[^0-9]', '') AS phone_digits_only,
  c_pos + 1 AS contact_priority,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.contacts'), 'ARRAY<STRING>')) c_tbl AS c_pos, c