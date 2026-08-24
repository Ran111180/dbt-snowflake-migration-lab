{# adv_json_schema_validation: TYPEOF, IS_OBJECT, IS_ARRAY, IS_NULL_VALUE #}
{{ config(materialized='table', tags=['advanced', 'data_quality']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  -- Type checks
  TYPEOF(raw_data:patient_id) AS patient_id_type,
  TYPEOF(raw_data:diagnoses) AS diagnoses_type,
  TYPEOF(raw_data:vitals) AS vitals_type,
  -- Validate expected structure
  IS_OBJECT(raw_data:vitals) AS vitals_is_object,
  IS_ARRAY(raw_data:diagnoses) AS diagnoses_is_array,
  IS_NULL_VALUE(raw_data:discharge_date) AS discharge_is_null,
  -- Schema completeness score
  (
    IFF(raw_data:patient_id IS NOT NULL, 1, 0) +
    IFF(raw_data:name IS NOT NULL, 1, 0) +
    IFF(raw_data:dob IS NOT NULL, 1, 0) +
    IFF(raw_data:gender IS NOT NULL, 1, 0) +
    IFF(raw_data:diagnoses IS NOT NULL, 1, 0) +
    IFF(raw_data:medications IS NOT NULL, 1, 0) +
    IFF(raw_data:vitals IS NOT NULL, 1, 0) +
    IFF(raw_data:insurance IS NOT NULL, 1, 0)
  ) AS fields_present,
  8 AS fields_expected,
  ROUND((
    IFF(raw_data:patient_id IS NOT NULL, 1, 0) +
    IFF(raw_data:name IS NOT NULL, 1, 0) +
    IFF(raw_data:dob IS NOT NULL, 1, 0) +
    IFF(raw_data:gender IS NOT NULL, 1, 0) +
    IFF(raw_data:diagnoses IS NOT NULL, 1, 0) +
    IFF(raw_data:medications IS NOT NULL, 1, 0) +
    IFF(raw_data:vitals IS NOT NULL, 1, 0) +
    IFF(raw_data:insurance IS NOT NULL, 1, 0)
  ) / 8.0 * 100, 1) AS completeness_pct,
  IFF(IS_ARRAY(raw_data:diagnoses) AND ARRAY_SIZE(raw_data:diagnoses) > 0, 'HAS_DX', 'NO_DX') AS dx_status,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
