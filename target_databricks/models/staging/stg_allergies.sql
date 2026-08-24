{# stg_allergies: VARIANT FLATTEN array, QUALIFY dedup #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(f, '$.allergen') AS STRING) AS allergen,
  CAST(GET_JSON_OBJECT(f, '$.reaction') AS STRING) AS reaction_type,
  CAST(GET_JSON_OBJECT(f, '$.severity') AS STRING) AS severity,
  DATE(TRY_TO_TIMESTAMP(CAST(GET_JSON_OBJECT(f, '$.reported_date') AS STRING), 'yyyy-MM-dd')) AS reported_date,
  f_pos + 1 AS allergy_seq,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.allergies'), 'ARRAY<STRING>')) f_tbl AS f_pos, f
QUALIFY
  ROW_NUMBER() OVER (
    PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING), CAST(GET_JSON_OBJECT(f, '$.allergen') AS STRING)
    ORDER BY _ingested_at DESC NULLS FIRST
  ) = 1