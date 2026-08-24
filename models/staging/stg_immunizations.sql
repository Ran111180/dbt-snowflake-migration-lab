{# stg_immunizations: VARIANT array, position index, DATEADD #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  f.value:vaccine_name::STRING AS vaccine_name,
  f.value:vaccine_code::STRING AS vaccine_code,
  TRY_TO_DATE(f.value:administered_date::STRING) AS administered_date,
  f.value:dose_number::NUMBER AS dose_number,
  f.value:site::STRING AS injection_site,
  f.index + 1 AS immunization_seq,
  DATEDIFF('day', TRY_TO_DATE(f.value:administered_date::STRING), CURRENT_DATE()) AS days_since_vaccination,
  IFF(DATEDIFF('year', TRY_TO_DATE(f.value:administered_date::STRING), CURRENT_DATE()) > 1, TRUE, FALSE) AS needs_booster,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }},
  LATERAL FLATTEN(input => raw_data:immunizations) f
WHERE f.value:vaccine_name IS NOT NULL
