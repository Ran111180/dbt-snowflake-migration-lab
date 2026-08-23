{# dim_patients: SCD Type 2 dimension using dbt snapshot pattern #}
{{ config(
    materialized='table',
    tags=['marts', 'gold', 'dimension']
) }}

WITH current_data AS (
  SELECT
    patient_id,
    full_name,
    age,
    gender,
    race,
    preferred_language,
    city,
    state,
    zip_code,
    facility_id,
    is_current_resident,
    diagnosis_count,
    medication_count,
    ssn_hash,
    _ingested_at AS valid_from,
    MD5(
      CONCAT_WS(
        '|',
        COALESCE(CAST(patient_id AS STRING), '_null_'),
        COALESCE(CAST(full_name AS STRING), '_null_'),
        COALESCE(CAST(facility_id AS STRING), '_null_'),
        COALESCE(CAST(city AS STRING), '_null_'),
        COALESCE(CAST(state AS STRING), '_null_')
      )
    ) AS row_hash
  FROM {{ ref('stg_patients') }}
)
SELECT
  MD5(CONCAT_WS('|', COALESCE(CAST(patient_id AS STRING), '_null_'))) AS patient_key,
  patient_id,
  full_name,
  age,
  gender,
  race,
  preferred_language,
  city,
  state,
  zip_code,
  facility_id,
  is_current_resident,
  diagnosis_count,
  medication_count,
  ssn_hash,
  valid_from,
  CAST('9999-12-31' AS DATE) AS valid_to,
  TRUE AS is_current,
  row_hash
FROM current_data