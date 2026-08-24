{# stg_vital_alerts: Nested IFF 4-deep, NVL2, DECODE #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) AS heart_rate,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.systolic_bp') AS DECIMAL(38, 0)) AS systolic_bp,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.diastolic_bp') AS DECIMAL(38, 0)) AS diastolic_bp,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.temperature') AS DOUBLE) AS temperature,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.o2_sat') AS DECIMAL(38, 0)) AS o2_saturation,
  IF(
    CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) > 150,
    'CRITICAL',
    IF(
      CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) > 120,
      'HIGH',
      IF(
        CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) > 100,
        'MODERATE',
        IF(CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) < 50, 'LOW_HR', 'NORMAL')
      )
    )
  ) AS hr_alert_level, /* Nested IFF 4-deep for alert severity */
  NVL2(
    GET_JSON_OBJECT(raw_data, '$.vitals.o2_sat'),
    IF(CAST(GET_JSON_OBJECT(raw_data, '$.vitals.o2_sat') AS DECIMAL(38, 0)) < 90, 'HYPOXIC', 'NORMAL'),
    'NOT_MEASURED'
  ) AS o2_status, /* NVL2: if value exists use it, otherwise default */
  DECODE(
    CAST(GET_JSON_OBJECT(raw_data, '$.vitals.position') AS STRING),
    'supine',
    'Lying Down',
    'sitting',
    'Seated',
    'standing',
    'Upright',
    'Unknown'
  ) AS patient_position, /* DECODE for categorical mapping */
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
WHERE
  GET_JSON_OBJECT(raw_data, '$.vitals') IS NOT NULL