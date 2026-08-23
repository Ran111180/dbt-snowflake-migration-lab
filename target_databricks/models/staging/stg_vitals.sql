{# stg_vitals: VARIANT vitals extraction, CASE expressions, clinical thresholds #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.bp_systolic') AS DECIMAL(38, 0)) AS bp_systolic,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.bp_diastolic') AS DECIMAL(38, 0)) AS bp_diastolic,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) AS heart_rate,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.temperature') AS DOUBLE) AS temperature_f,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.weight_lbs') AS DOUBLE) AS weight_lbs,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.o2_saturation') AS DECIMAL(38, 0)) AS o2_saturation,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.pain_level') AS DECIMAL(38, 0)) AS pain_level,
  TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.vitals.recorded_at') AS STRING) AS TIMESTAMP) AS recorded_at,
  CASE
    WHEN CAST(GET_JSON_OBJECT(raw_data, '$.vitals.bp_systolic') AS DECIMAL(38, 0)) >= 180
    OR CAST(GET_JSON_OBJECT(raw_data, '$.vitals.bp_diastolic') AS DECIMAL(38, 0)) >= 120
    THEN 'Hypertensive Crisis'
    WHEN CAST(GET_JSON_OBJECT(raw_data, '$.vitals.bp_systolic') AS DECIMAL(38, 0)) >= 140
    OR CAST(GET_JSON_OBJECT(raw_data, '$.vitals.bp_diastolic') AS DECIMAL(38, 0)) >= 90
    THEN 'Stage 2 HTN'
    WHEN CAST(GET_JSON_OBJECT(raw_data, '$.vitals.bp_systolic') AS DECIMAL(38, 0)) >= 130
    OR CAST(GET_JSON_OBJECT(raw_data, '$.vitals.bp_diastolic') AS DECIMAL(38, 0)) >= 80
    THEN 'Stage 1 HTN'
    WHEN CAST(GET_JSON_OBJECT(raw_data, '$.vitals.bp_systolic') AS DECIMAL(38, 0)) >= 120
    THEN 'Elevated'
    ELSE 'Normal'
  END AS bp_classification, /* Clinical classifications */
  IF(
    CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) < 60,
    'Bradycardia',
    IF(CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) > 100, 'Tachycardia', 'Normal')
  ) AS hr_classification,
  IF(CAST(GET_JSON_OBJECT(raw_data, '$.vitals.temperature') AS DOUBLE) > 100.4, TRUE, FALSE) AS has_fever,
  IF(
    CAST(GET_JSON_OBJECT(raw_data, '$.vitals.o2_saturation') AS DECIMAL(38, 0)) < 90,
    'Critical',
    IF(CAST(GET_JSON_OBJECT(raw_data, '$.vitals.o2_saturation') AS DECIMAL(38, 0)) < 94, 'Low', 'Normal')
  ) AS o2_classification,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}