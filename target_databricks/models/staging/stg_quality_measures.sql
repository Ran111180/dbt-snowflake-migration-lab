{# stg_quality_measures: VARIANT scores, WIDTH_BUCKET for quality tiers #}
{{ config(materialized='view', tags=['staging', 'quality']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.facility_id') AS STRING) AS facility_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.measure_id') AS STRING) AS measure_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.measure_name') AS STRING) AS measure_name,
  CAST(GET_JSON_OBJECT(raw_data, '$.score') AS DOUBLE) AS score,
  CAST(GET_JSON_OBJECT(raw_data, '$.benchmark') AS DOUBLE) AS benchmark,
  CAST(GET_JSON_OBJECT(raw_data, '$.score') AS DOUBLE) - CAST(GET_JSON_OBJECT(raw_data, '$.benchmark') AS DOUBLE) AS variance_from_benchmark,
  IF(
    CAST(GET_JSON_OBJECT(raw_data, '$.benchmark') AS DOUBLE) = 0
    OR CAST(GET_JSON_OBJECT(raw_data, '$.benchmark') AS DOUBLE) IS NULL,
    0,
    CAST(GET_JSON_OBJECT(raw_data, '$.score') AS DOUBLE) / CAST(GET_JSON_OBJECT(raw_data, '$.benchmark') AS DOUBLE)
  ) AS score_to_benchmark_ratio,
  WIDTH_BUCKET(CAST(GET_JSON_OBJECT(raw_data, '$.score') AS DOUBLE), 0, 100, 5) AS quality_tier,
  CASE
    WHEN CAST(GET_JSON_OBJECT(raw_data, '$.score') AS DOUBLE) >= CAST(GET_JSON_OBJECT(raw_data, '$.benchmark') AS DOUBLE) * 1.1
    THEN 'EXCEEDS'
    WHEN CAST(GET_JSON_OBJECT(raw_data, '$.score') AS DOUBLE) >= CAST(GET_JSON_OBJECT(raw_data, '$.benchmark') AS DOUBLE)
    THEN 'MEETS'
    WHEN CAST(GET_JSON_OBJECT(raw_data, '$.score') AS DOUBLE) >= CAST(GET_JSON_OBJECT(raw_data, '$.benchmark') AS DOUBLE) * 0.8
    THEN 'BELOW'
    ELSE 'CRITICAL'
  END AS performance_status,
  _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}
WHERE
  GET_JSON_OBJECT(raw_data, '$.measure_id') IS NOT NULL