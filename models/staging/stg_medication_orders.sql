{# stg_medication_orders: ARRAY_CONSTRUCT, ARRAY_APPEND, ARRAY_CAT #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  raw_data:encounter_id::STRING AS encounter_id,
  f.value:drug_name::STRING AS medication_name,
  f.value:dose::STRING AS dose,
  f.value:route::STRING AS route,
  f.value:frequency::STRING AS frequency,
  ARRAY_CONSTRUCT(
    f.value:drug_name::STRING,
    f.value:dose::STRING,
    f.value:route::STRING
  ) AS med_summary_array,
  ARRAY_SIZE(raw_data:medications) AS total_medications,
  f.index + 1 AS order_sequence,
  TRY_TO_TIMESTAMP(f.value:ordered_at::STRING) AS ordered_at,
  TRY_TO_TIMESTAMP(f.value:administered_at::STRING) AS administered_at,
  DATEDIFF('minute',
    TRY_TO_TIMESTAMP(f.value:ordered_at::STRING),
    TRY_TO_TIMESTAMP(f.value:administered_at::STRING)
  ) AS minutes_to_administer,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }},
  LATERAL FLATTEN(input => raw_data:medications) f
