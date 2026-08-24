{# adv_object_agg: ARRAY_AGG with ordering and LISTAGG patterns #}
{{ config(materialized='table', tags=['advanced', 'aggregation']) }}

SELECT
  patient_id,
  ARRAY_AGG(DISTINCT icd10_code) WITHIN GROUP (ORDER BY icd10_code) AS dx_codes_sorted,
  COUNT(DISTINCT icd10_code) AS unique_dx_count,
  MAX(onset_date) AS latest_dx_date,
  LISTAGG(DISTINCT severity, ', ') WITHIN GROUP (ORDER BY severity) AS severity_list,
  LISTAGG(DISTINCT icd10_code, '|') WITHIN GROUP (ORDER BY icd10_code) AS all_codes_pipe
FROM {{ ref('stg_diagnoses') }}
GROUP BY patient_id
HAVING COUNT(DISTINCT icd10_code) >= 1
