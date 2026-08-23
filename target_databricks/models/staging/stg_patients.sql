{# stg_patients: VARIANT path notation, type casting, IFF, DATEDIFF, ARRAY_SIZE #}
{{ config(materialized='view', tags=['staging', 'patients']) }}

WITH raw AS (
  SELECT
    raw_data,
    _ingested_at,
    _source_file,
    _batch_id
  FROM {{ source('landing', 'raw_patients') }}
)
SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.demographics.first_name') AS STRING) AS first_name,
  CAST(GET_JSON_OBJECT(raw_data, '$.demographics.last_name') AS STRING) AS last_name,
  CONCAT(
    CAST(GET_JSON_OBJECT(raw_data, '$.demographics.first_name') AS STRING),
    ' ',
    CAST(GET_JSON_OBJECT(raw_data, '$.demographics.last_name') AS STRING)
  ) AS full_name,
  CAST(GET_JSON_OBJECT(raw_data, '$.demographics.dob') AS DATE) AS date_of_birth,
  DATEDIFF(YEAR, CAST(GET_JSON_OBJECT(raw_data, '$.demographics.dob') AS DATE), CURRENT_DATE()) AS age,
  CAST(GET_JSON_OBJECT(raw_data, '$.demographics.gender') AS STRING) AS gender,
  CAST(GET_JSON_OBJECT(raw_data, '$.demographics.race') AS STRING) AS race,
  CAST(GET_JSON_OBJECT(raw_data, '$.demographics.language') AS STRING) AS preferred_language,
  CAST(GET_JSON_OBJECT(raw_data, '$.demographics.marital_status') AS STRING) AS marital_status,
  SHA2(CAST(GET_JSON_OBJECT(raw_data, '$.demographics.ssn') AS STRING), 256) AS ssn_hash,
  CAST(GET_JSON_OBJECT(raw_data, '$.address.street') AS STRING) AS street,
  CAST(GET_JSON_OBJECT(raw_data, '$.address.city') AS STRING) AS city,
  CAST(GET_JSON_OBJECT(raw_data, '$.address.state') AS STRING) AS state,
  CAST(GET_JSON_OBJECT(raw_data, '$.address.zip') AS STRING) AS zip_code,
  CAST(GET_JSON_OBJECT(raw_data, '$.facility_id') AS STRING) AS facility_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.admit_date') AS DATE) AS admit_date,
  CAST(GET_JSON_OBJECT(raw_data, '$.discharge_date') AS DATE) AS discharge_date,
  IF(GET_JSON_OBJECT(raw_data, '$.discharge_date') IS NULL, TRUE, FALSE) AS is_current_resident,
  DATEDIFF(
    DAY,
    CAST(GET_JSON_OBJECT(raw_data, '$.admit_date') AS DATE),
    COALESCE(CAST(GET_JSON_OBJECT(raw_data, '$.discharge_date') AS DATE), CURRENT_DATE())
  ) AS length_of_stay,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.bp_systolic') AS DECIMAL(38, 0)) AS bp_systolic,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.bp_diastolic') AS DECIMAL(38, 0)) AS bp_diastolic,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.heart_rate') AS DECIMAL(38, 0)) AS heart_rate,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.temperature') AS DOUBLE) AS temperature_f,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.weight_lbs') AS DOUBLE) AS weight_lbs,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.o2_saturation') AS DECIMAL(38, 0)) AS o2_saturation,
  CAST(GET_JSON_OBJECT(raw_data, '$.vitals.pain_level') AS DECIMAL(38, 0)) AS pain_level,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.diagnoses'), 'ARRAY<STRING>')) AS diagnosis_count,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.medications'), 'ARRAY<STRING>')) AS medication_count,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.lab_results'), 'ARRAY<STRING>')) AS lab_result_count,
  CAST(GET_JSON_OBJECT(raw_data, '$.notes') AS STRING) AS clinical_notes,
  _ingested_at,
  _source_file,
  _batch_id
FROM raw