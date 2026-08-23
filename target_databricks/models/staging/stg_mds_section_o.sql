{# stg_mds_section_o: FLATTEN Section O treatments, IFF pattern matching #}
{{ config(materialized='view', tags=['staging', 'mds']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(tx AS STRING) AS section_o_service,
  tx_pos + 1 AS service_position,
  'Section_O' AS mds_section,
  IF(CAST(tx AS STRING) LIKE '%injectable%', TRUE, FALSE) AS is_injectable,
  IF(
    CAST(tx AS STRING) LIKE '%iv%' OR CAST(tx AS STRING) LIKE '%IV%',
    TRUE,
    FALSE
  ) AS is_iv_service,
  IF(CAST(tx AS STRING) LIKE '%therapy%', TRUE, FALSE) AS is_therapy,
  REGEXP_EXTRACT(CAST(tx AS STRING), 'O[0-9]{4}', 0) AS service_code,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.mds_assessment.section_o'), 'ARRAY<STRING>')) tx_tbl AS tx_pos, tx