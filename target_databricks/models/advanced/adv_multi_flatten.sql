{# adv_multi_flatten: 3 concurrent LATERAL FLATTEN cross-join style #}
{{ config(materialized='table', tags=['advanced', 'complex']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(d, '$.icd10') AS STRING) AS diagnosis_code,
  CAST(GET_JSON_OBJECT(d, '$.description') AS STRING) AS diagnosis_desc,
  CAST(GET_JSON_OBJECT(m, '$.drug_name') AS STRING) AS medication_name,
  CAST(GET_JSON_OBJECT(m, '$.dose') AS STRING) AS dose,
  CAST(GET_JSON_OBJECT(i, '$.payer') AS STRING) AS insurance_payer,
  CAST(GET_JSON_OBJECT(i, '$.plan_type') AS STRING) AS plan_type,
  d_pos /* Cross-product analysis: which meds are prescribed for which diagnoses under which insurance */ + 1 AS dx_seq,
  m_pos + 1 AS med_seq,
  i_pos + 1 AS ins_seq,
  CONCAT(
    CAST(GET_JSON_OBJECT(d, '$.icd10') AS STRING),
    '|',
    CAST(GET_JSON_OBJECT(m, '$.drug_name') AS STRING),
    '|',
    CAST(GET_JSON_OBJECT(i, '$.payer') AS STRING)
  ) AS combination_key,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.diagnoses'), 'ARRAY<STRING>')) d_tbl AS d_pos, d
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.medications'), 'ARRAY<STRING>')) m_tbl AS m_pos, m
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.insurance'), 'ARRAY<STRING>')) i_tbl AS i_pos, i
WHERE
  CAST(GET_JSON_OBJECT(d, '$.is_primary') AS BOOLEAN) = TRUE
QUALIFY
  ROW_NUMBER() OVER (
    PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING), CAST(GET_JSON_OBJECT(d, '$.icd10') AS STRING)
    ORDER BY m_pos ASC NULLS LAST, i_pos ASC NULLS LAST
  ) <= 5