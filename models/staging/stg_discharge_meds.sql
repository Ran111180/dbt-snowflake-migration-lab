{# stg_discharge_meds: FLATTEN + REGEXP_LIKE for medication filtering #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  raw_data:encounter_id::STRING AS encounter_id,
  f.value:drug_name::STRING AS medication_name,
  f.value:dose::STRING AS dose,
  f.value:frequency::STRING AS frequency,
  f.value:route::STRING AS route,
  IFF(REGEXP_LIKE(f.value:drug_name::STRING, '.*(statin|atorvastatin|rosuvastatin).*', 'i'), TRUE, FALSE) AS is_statin,
  IFF(REGEXP_LIKE(f.value:drug_name::STRING, '.*(pril|sartan).*', 'i'), TRUE, FALSE) AS is_ace_arb,
  IFF(REGEXP_LIKE(f.value:drug_name::STRING, '.*(olol|dilol).*', 'i'), TRUE, FALSE) AS is_beta_blocker,
  IFF(REGEXP_LIKE(f.value:route::STRING, '^(IV|IM|SubQ)$', 'i'), TRUE, FALSE) AS is_injectable,
  f.index + 1 AS medication_seq,
  ARRAY_SIZE(raw_data:discharge_medications) AS total_discharge_meds,
  _ingested_at
FROM {{ source('landing', 'raw_encounters') }},
  LATERAL FLATTEN(input => raw_data:discharge_medications) f
