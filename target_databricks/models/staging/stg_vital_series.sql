{# stg_vital_series: Time-series VARIANT, LAG/LEAD for trend detection #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) AS heart_rate,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.systolic_bp') AS DECIMAL(38, 0)) AS systolic_bp,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.temperature') AS DOUBLE) AS temperature,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.o2_sat') AS DECIMAL(38, 0)) AS o2_sat,
  _ingested_at AS reading_time,
  LAG(CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0))) OVER (
    PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING)
    ORDER BY _ingested_at ASC NULLS LAST
  ) AS prev_heart_rate, /* Trend detection via LAG/LEAD */
  LEAD(CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0))) OVER (
    PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING)
    ORDER BY _ingested_at ASC NULLS LAST
  ) AS next_heart_rate,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) - LAG(CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0))) OVER (
    PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING)
    ORDER BY _ingested_at ASC NULLS LAST
  ) AS hr_change,
  IF(
    ABS(
      CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) - LAG(CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0))) OVER (
        PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING)
        ORDER BY _ingested_at ASC NULLS LAST
      )
    ) > 20,
    'RAPID_CHANGE',
    'STABLE'
  ) AS hr_trend
FROM {{ source('landing', 'raw_patients') }}
WHERE
  GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') IS NOT NULL