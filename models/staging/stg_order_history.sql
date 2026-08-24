{# stg_order_history: FLATTEN + RATIO_TO_REPORT for cost distribution #}
{{ config(materialized='view', tags=['staging', 'billing']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  raw_data:encounter_id::STRING AS encounter_id,
  f.value:order_type::STRING AS order_type,
  f.value:description::STRING AS order_description,
  f.value:charge::FLOAT AS order_charge,
  f.index + 1 AS order_sequence,
  RATIO_TO_REPORT(f.value:charge::FLOAT) OVER (
    PARTITION BY raw_data:encounter_id::STRING
  ) AS charge_pct_of_encounter,
  SUM(f.value:charge::FLOAT) OVER (
    PARTITION BY raw_data:encounter_id::STRING
  ) AS encounter_total_charges,
  _ingested_at
FROM {{ source('landing', 'raw_encounters') }},
  LATERAL FLATTEN(input => raw_data:orders) f
WHERE f.value:charge::FLOAT > 0
