{# stg_lab_panels: VARIANT nested lab panels, FLATTEN + aggregation #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  raw_data:panel_name::STRING AS panel_name,
  f.value:test_name::STRING AS test_name,
  f.value:result::FLOAT AS result_value,
  f.value:unit::STRING AS unit,
  f.value:reference_low::FLOAT AS ref_low,
  f.value:reference_high::FLOAT AS ref_high,
  IFF(f.value:result::FLOAT < f.value:reference_low::FLOAT, 'LOW',
    IFF(f.value:result::FLOAT > f.value:reference_high::FLOAT, 'HIGH', 'NORMAL')
  ) AS result_flag,
  f.value:result::FLOAT - f.value:reference_low::FLOAT AS deviation_from_low,
  f.value:result::FLOAT - f.value:reference_high::FLOAT AS deviation_from_high,
  f.index + 1 AS test_sequence,
  ARRAY_SIZE(raw_data:results) AS tests_in_panel,
  TRY_TO_TIMESTAMP(raw_data:collected_at::STRING) AS collected_at,
  _ingested_at
FROM {{ source('landing', 'raw_lab_results') }},
  LATERAL FLATTEN(input => raw_data:results) f
