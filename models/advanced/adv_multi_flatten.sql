{# adv_multi_flatten: 3 concurrent LATERAL FLATTEN cross-join style #}
{{ config(materialized='table', tags=['advanced', 'complex']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  d.value:icd10::STRING AS diagnosis_code,
  d.value:description::STRING AS diagnosis_desc,
  m.value:drug_name::STRING AS medication_name,
  m.value:dose::STRING AS dose,
  i.value:payer::STRING AS insurance_payer,
  i.value:plan_type::STRING AS plan_type,
  -- Cross-product analysis: which meds are prescribed for which diagnoses under which insurance
  d.index + 1 AS dx_seq,
  m.index + 1 AS med_seq,
  i.index + 1 AS ins_seq,
  CONCAT(d.value:icd10::STRING, '|', m.value:drug_name::STRING, '|', i.value:payer::STRING) AS combination_key,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }},
  LATERAL FLATTEN(input => raw_data:diagnoses) d,
  LATERAL FLATTEN(input => raw_data:medications) m,
  LATERAL FLATTEN(input => raw_data:insurance) i
WHERE
  d.value:is_primary::BOOLEAN = TRUE
QUALIFY
  ROW_NUMBER() OVER (
    PARTITION BY raw_data:patient_id::STRING, d.value:icd10::STRING
    ORDER BY m.index, i.index
  ) <= 5
