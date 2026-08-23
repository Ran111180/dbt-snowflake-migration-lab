{# stg_insurance: FLATTEN insurance array, OBJECT_KEYS pattern #}
{{ config(materialized='view', tags=['staging', 'patients']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(ins, '$.payer') AS STRING) AS payer_name,
  CAST(GET_JSON_OBJECT(ins, '$.plan_id') AS STRING) AS plan_id,
  CAST(GET_JSON_OBJECT(ins, '$.group_id') AS STRING) AS group_id,
  CAST(GET_JSON_OBJECT(ins, '$.type') AS STRING) AS coverage_type,
  TRY_CAST(CAST(GET_JSON_OBJECT(ins, '$.effective_date') AS STRING) AS DATE) AS effective_date,
  ins_pos + 1 AS insurance_rank,
  IF(CAST(GET_JSON_OBJECT(ins, '$.type') AS STRING) = 'Primary', TRUE, FALSE) AS is_primary,
  DATEDIFF(MONTH, TRY_CAST(CAST(GET_JSON_OBJECT(ins, '$.effective_date') AS STRING) AS DATE), CURRENT_DATE()) AS months_enrolled,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.insurance'), 'ARRAY<STRING>')) ins_tbl AS ins_pos, ins