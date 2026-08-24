{# stg_patient_consents: TRY_TO_NUMBER, TRY_TO_DATE, TRY_PARSE_JSON #}
{{ config(materialized='view', tags=['staging', 'administrative']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  TRY_TO_NUMBER(raw_data:consent_form_id::STRING) AS consent_form_id,
  TRY_TO_DATE(raw_data:consent_date::STRING, 'YYYY-MM-DD') AS consent_date,
  TRY_TO_DATE(raw_data:expiry_date::STRING, 'YYYY-MM-DD') AS expiry_date,
  raw_data:consent_type::STRING AS consent_type,
  IFF(TRY_TO_DATE(raw_data:expiry_date::STRING) >= CURRENT_DATE(), TRUE, FALSE) AS is_active,
  DATEDIFF('day',
    TRY_TO_DATE(raw_data:consent_date::STRING),
    COALESCE(TRY_TO_DATE(raw_data:expiry_date::STRING), CURRENT_DATE())
  ) AS days_since_consent,
  TRY_TO_NUMBER(raw_data:version::STRING, 10, 2) AS form_version,
  raw_data:signed_by::STRING AS signed_by,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
WHERE raw_data:consent_date IS NOT NULL
