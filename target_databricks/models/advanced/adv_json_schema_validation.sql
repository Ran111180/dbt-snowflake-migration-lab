{# adv_json_schema_validation: TYPEOF, IS_OBJECT, IS_ARRAY, IS_NULL_VALUE #}
{{ config(materialized='table', tags=['advanced', 'data_quality']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  IF(GET_JSON_OBJECT(raw_data, '$.vitals') IS NOT NULL, TRUE, FALSE) AS vitals_is_present, /* Validate expected structure */
  IF(GET_JSON_OBJECT(raw_data, '$.diagnoses') IS NOT NULL, TRUE, FALSE) AS diagnoses_is_present,
  IF(GET_JSON_OBJECT(raw_data, '$.discharge_date') IS NULL, TRUE, FALSE) AS discharge_is_null,
  (
    IF(GET_JSON_OBJECT(raw_data, '$.patient_id') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.name') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.dob') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.gender') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.diagnoses') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.medications') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.vitals') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.insurance') IS NOT NULL, 1, 0)
  ) AS fields_present, /* Schema completeness score */
  8 AS fields_expected,
  ROUND(
    (
      IF(GET_JSON_OBJECT(raw_data, '$.patient_id') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.name') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.dob') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.gender') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.diagnoses') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.medications') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.vitals') IS NOT NULL, 1, 0) + IF(GET_JSON_OBJECT(raw_data, '$.insurance') IS NOT NULL, 1, 0)
    ) / 8.0 * 100,
    1
  ) AS completeness_pct,
  IF((GET_JSON_OBJECT(raw_data, '$.diagnoses' IS NOT NULL)) AND SIZE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.diagnoses'), 'ARRAY<STRING>')) > 0, 'HAS_DX', 'NO_DX') AS dx_status,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}