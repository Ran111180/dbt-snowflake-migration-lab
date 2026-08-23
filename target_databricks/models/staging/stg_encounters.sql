{# stg_encounters: VARIANT nested objects, DATEADD, DATEDIFF, NVL2, COALESCE #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING) AS encounter_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.facility_id') AS STRING) AS facility_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.encounter_type') AS STRING) AS encounter_type,
  TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.admit_datetime') AS STRING) AS TIMESTAMP) AS admit_datetime,
  TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.discharge_datetime') AS STRING) AS TIMESTAMP) AS discharge_datetime,
  CAST(GET_JSON_OBJECT(raw_data, '$.attending_provider.npi') AS STRING) AS provider_npi,
  CAST(GET_JSON_OBJECT(raw_data, '$.attending_provider.name') AS STRING) AS provider_name,
  CAST(GET_JSON_OBJECT(raw_data, '$.attending_provider.specialty') AS STRING) AS provider_specialty,
  CAST(GET_JSON_OBJECT(raw_data, '$.charges.room_and_board') AS DOUBLE) AS charge_room_board,
  CAST(GET_JSON_OBJECT(raw_data, '$.charges.pharmacy') AS DOUBLE) AS charge_pharmacy,
  CAST(GET_JSON_OBJECT(raw_data, '$.charges.supplies') AS DOUBLE) AS charge_supplies,
  CAST(GET_JSON_OBJECT(raw_data, '$.charges.professional') AS DOUBLE) AS charge_professional,
  CAST(GET_JSON_OBJECT(raw_data, '$.charges.total') AS DOUBLE) AS total_charges,
  CAST(GET_JSON_OBJECT(raw_data, '$.discharge_disposition') AS STRING) AS discharge_disposition,
  CAST(GET_JSON_OBJECT(raw_data, '$.payer_id') AS STRING) AS payer_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.authorization.auth_number') AS STRING) AS auth_number,
  CAST(GET_JSON_OBJECT(raw_data, '$.authorization.approved_days') AS DECIMAL(38, 0)) AS approved_days,
  CAST(GET_JSON_OBJECT(raw_data, '$.authorization.used_days') AS DECIMAL(38, 0)) AS used_days,
  CAST(GET_JSON_OBJECT(raw_data, '$.authorization.status') AS STRING) AS auth_status,
  NVL2(
    GET_JSON_OBJECT(raw_data, '$.discharge_datetime'),
    DATEDIFF(
      HOUR,
      TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.admit_datetime') AS STRING) AS TIMESTAMP),
      TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.discharge_datetime') AS STRING) AS TIMESTAMP)
    ),
    DATEDIFF(
      HOUR,
      TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.admit_datetime') AS STRING) AS TIMESTAMP),
      CURRENT_TIMESTAMP()
    )
  ) AS total_hours,
  COALESCE(CAST(GET_JSON_OBJECT(raw_data, '$.authorization.approved_days') AS DECIMAL(38, 0)), 0) - COALESCE(CAST(GET_JSON_OBJECT(raw_data, '$.authorization.used_days') AS DECIMAL(38, 0)), 0) AS remaining_auth_days,
  IF(CAST(GET_JSON_OBJECT(raw_data, '$.authorization.status') AS STRING) = 'Denied', TRUE, FALSE) AS is_auth_denied,
  CAST(DATEADD(
    DAY,
    COALESCE(CAST(GET_JSON_OBJECT(raw_data, '$.authorization.approved_days') AS DECIMAL(38, 0)), 0),
    TRY_CAST(CAST(GET_JSON_OBJECT(raw_data, '$.admit_datetime') AS STRING) AS TIMESTAMP)
  ) AS DATE) AS auth_expiry_date,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.procedures'), 'ARRAY<STRING>')) AS procedure_count,
  SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.diagnosis_codes'), 'ARRAY<STRING>')) AS diagnosis_code_count,
  _ingested_at
FROM {{ source('landing', 'raw_encounters') }}