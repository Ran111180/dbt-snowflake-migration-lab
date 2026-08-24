{# dim_providers: SCD Type 2 logic + hierarchy #}
{{ config(materialized='table', tags=['marts', 'dimension']) }}

WITH provider_data AS (
  SELECT
    CAST(GET_JSON_OBJECT(raw_data, '$.provider_id') AS STRING) AS provider_id,
    CAST(GET_JSON_OBJECT(raw_data, '$.name') AS STRING) AS provider_name,
    CAST(GET_JSON_OBJECT(raw_data, '$.specialty') AS STRING) AS specialty,
    CAST(GET_JSON_OBJECT(raw_data, '$.department') AS STRING) AS department,
    CAST(GET_JSON_OBJECT(raw_data, '$.facility_id') AS STRING) AS facility_id,
    CAST(GET_JSON_OBJECT(raw_data, '$.hire_date') AS DATE) AS hire_date,
    CAST(GET_JSON_OBJECT(raw_data, '$.is_active') AS BOOLEAN) AS is_active,
    _ingested_at,
    ROW_NUMBER() OVER (
      PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.provider_id') AS STRING)
      ORDER BY _ingested_at DESC NULLS FIRST
    ) AS rn
  FROM {{ source('landing', 'raw_facility_ops') }}
  WHERE
    GET_JSON_OBJECT(raw_data, '$.provider_id') IS NOT NULL
)
SELECT
  MD5(CONCAT(provider_id, '|', CAST(_ingested_at AS STRING))) AS provider_key,
  provider_id,
  provider_name,
  specialty,
  department,
  facility_id,
  hire_date,
  is_active,
  _ingested_at AS valid_from,
  LEAD(_ingested_at) OVER (PARTITION BY provider_id ORDER BY _ingested_at ASC NULLS LAST) AS valid_to,
  IF(rn = 1, TRUE, FALSE) AS is_current,
  DATEDIFF(YEAR, hire_date, CURRENT_DATE()) AS years_of_service
FROM provider_data