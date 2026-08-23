{# stg_lab_results: LATERAL FLATTEN nested arrays, CASE, NVL, window LAG #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.order_id') AS STRING) AS order_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.test_panel') AS STRING) AS test_panel,
  CAST(GET_JSON_OBJECT(r, '$.analyte') AS STRING) AS analyte_name,
  CAST(GET_JSON_OBJECT(r, '$.value') AS DOUBLE) AS result_value,
  CAST(GET_JSON_OBJECT(r, '$.unit') AS STRING) AS unit,
  CAST(GET_JSON_OBJECT(r, '$.ref_low') AS DOUBLE) AS reference_low,
  CAST(GET_JSON_OBJECT(r, '$.ref_high') AS DOUBLE) AS reference_high,
  COALESCE(CAST(GET_JSON_OBJECT(r, '$.flag') AS STRING), 'NORMAL') AS result_flag,
  CASE
    WHEN CAST(GET_JSON_OBJECT(r, '$.value') AS DOUBLE) < CAST(GET_JSON_OBJECT(r, '$.ref_low') AS DOUBLE)
    THEN 'Below Normal'
    WHEN CAST(GET_JSON_OBJECT(r, '$.value') AS DOUBLE) > CAST(GET_JSON_OBJECT(r, '$.ref_high') AS DOUBLE)
    THEN 'Above Normal'
    ELSE 'Normal'
  END AS interpretation,
  TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.collected_at') AS STRING) AS TIMESTAMP) AS collected_at,
  TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.resulted_at') AS STRING) AS TIMESTAMP) AS resulted_at,
  DATEDIFF(
    HOUR,
    TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.collected_at') AS STRING) AS TIMESTAMP),
    TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.resulted_at') AS STRING) AS TIMESTAMP)
  ) AS turnaround_hours,
  CAST(GET_JSON_OBJECT(raw_data, '$.ordering_provider') AS STRING) AS ordering_provider,
  CAST(GET_JSON_OBJECT(raw_data, '$.status') AS STRING) AS result_status,
  CAST(GET_JSON_OBJECT(raw_data, '$.critical_flag') AS BOOLEAN) AS is_critical,
  LAG(CAST(GET_JSON_OBJECT(r, '$.value') AS DOUBLE)) OVER (
    PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING), CAST(GET_JSON_OBJECT(r, '$.analyte') AS STRING)
    ORDER BY TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.collected_at') AS STRING) AS TIMESTAMP) ASC NULLS LAST
  ) AS previous_value,
  CAST(GET_JSON_OBJECT(r, '$.value') AS DOUBLE) - COALESCE(
    LAG(CAST(GET_JSON_OBJECT(r, '$.value') AS DOUBLE)) OVER (
      PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING), CAST(GET_JSON_OBJECT(r, '$.analyte') AS STRING)
      ORDER BY TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.collected_at') AS STRING) AS TIMESTAMP) ASC NULLS LAST
    ),
    CAST(GET_JSON_OBJECT(r, '$.value') AS DOUBLE)
  ) AS value_change,
  _ingested_at
FROM {{ source('landing', 'raw_lab_results') }}
  LATERAL VIEW EXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.results'), 'ARRAY<STRING>')) r_tbl AS r