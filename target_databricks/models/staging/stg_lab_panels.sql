{# stg_lab_panels: VARIANT nested lab panels, FLATTEN + aggregation #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.panel_name') AS STRING) AS panel_name,
  CAST(GET_JSON_OBJECT(f, '$.test_name') AS STRING) AS test_name,
  CAST(GET_JSON_OBJECT(f, '$.result') AS DOUBLE) AS result_value,
  CAST(GET_JSON_OBJECT(f, '$.unit') AS STRING) AS unit,
  CAST(GET_JSON_OBJECT(f, '$.reference_low') AS DOUBLE) AS ref_low,
  CAST(GET_JSON_OBJECT(f, '$.reference_high') AS DOUBLE) AS ref_high,
  IF(
    CAST(GET_JSON_OBJECT(f, '$.result') AS DOUBLE) < CAST(GET_JSON_OBJECT(f, '$.reference_low') AS DOUBLE),
    'LOW',
    IF(
      CAST(GET_JSON_OBJECT(f, '$.result') AS DOUBLE) > CAST(GET_JSON_OBJECT(f, '$.reference_high') AS DOUBLE),
      'HIGH',
      'NORMAL'
    )
  ) AS result_flag,
  CAST(GET_JSON_OBJECT(f, '$.result') AS DOUBLE) - CAST(GET_JSON_OBJECT(f, '$.reference_low') AS DOUBLE) AS deviation_from_low,
  CAST(GET_JSON_OBJECT(f, '$.result') AS DOUBLE) - CAST(GET_JSON_OBJECT(f, '$.reference_high') AS DOUBLE) AS deviation_from_high,
  f_pos + 1 AS test_sequence,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.results'), 'ARRAY<STRING>')) AS tests_in_panel,
  TRY_TO_TIMESTAMP(CAST(GET_JSON_OBJECT(raw_data, '$.collected_at') AS STRING)) AS collected_at,
  _ingested_at
FROM {{ source('landing', 'raw_lab_results') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.results'), 'ARRAY<STRING>')) f_tbl AS f_pos, f