{# stg_quality_measures: VARIANT scores, WIDTH_BUCKET for quality tiers #}
{{ config(materialized='view', tags=['staging', 'quality']) }}

SELECT
  raw_data:facility_id::STRING AS facility_id,
  raw_data:measure_id::STRING AS measure_id,
  raw_data:measure_name::STRING AS measure_name,
  raw_data:score::FLOAT AS score,
  raw_data:benchmark::FLOAT AS benchmark,
  raw_data:score::FLOAT - raw_data:benchmark::FLOAT AS variance_from_benchmark,
  DIV0NULL(raw_data:score::FLOAT, raw_data:benchmark::FLOAT) AS score_to_benchmark_ratio,
  WIDTH_BUCKET(raw_data:score::FLOAT, 0, 100, 5) AS quality_tier,
  CASE
    WHEN raw_data:score::FLOAT >= raw_data:benchmark::FLOAT * 1.1 THEN 'EXCEEDS'
    WHEN raw_data:score::FLOAT >= raw_data:benchmark::FLOAT THEN 'MEETS'
    WHEN raw_data:score::FLOAT >= raw_data:benchmark::FLOAT * 0.8 THEN 'BELOW'
    ELSE 'CRITICAL'
  END AS performance_status,
  _ingested_at
FROM {{ source('landing', 'raw_facility_ops') }}
WHERE raw_data:measure_id IS NOT NULL
