{# stg_vital_series: Time-series VARIANT, LAG/LEAD for trend detection #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  raw_data:vitals.heart_rate::NUMBER AS heart_rate,
  raw_data:vitals.systolic_bp::NUMBER AS systolic_bp,
  raw_data:vitals.temperature::FLOAT AS temperature,
  raw_data:vitals.o2_sat::NUMBER AS o2_sat,
  _ingested_at AS reading_time,
  -- Trend detection via LAG/LEAD
  LAG(raw_data:vitals.heart_rate::NUMBER) OVER (
    PARTITION BY raw_data:patient_id::STRING ORDER BY _ingested_at
  ) AS prev_heart_rate,
  LEAD(raw_data:vitals.heart_rate::NUMBER) OVER (
    PARTITION BY raw_data:patient_id::STRING ORDER BY _ingested_at
  ) AS next_heart_rate,
  raw_data:vitals.heart_rate::NUMBER - LAG(raw_data:vitals.heart_rate::NUMBER) OVER (
    PARTITION BY raw_data:patient_id::STRING ORDER BY _ingested_at
  ) AS hr_change,
  IFF(ABS(raw_data:vitals.heart_rate::NUMBER - LAG(raw_data:vitals.heart_rate::NUMBER) OVER (
    PARTITION BY raw_data:patient_id::STRING ORDER BY _ingested_at
  )) > 20, 'RAPID_CHANGE', 'STABLE') AS hr_trend
FROM {{ source('landing', 'raw_patients') }}
WHERE raw_data:vitals.heart_rate IS NOT NULL
