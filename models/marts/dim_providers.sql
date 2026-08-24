{# dim_providers: SCD Type 2 logic + hierarchy #}
{{ config(materialized='table', tags=['marts', 'dimension']) }}

WITH provider_data AS (
  SELECT
    raw_data:provider_id::STRING AS provider_id,
    raw_data:name::STRING AS provider_name,
    raw_data:specialty::STRING AS specialty,
    raw_data:department::STRING AS department,
    raw_data:facility_id::STRING AS facility_id,
    raw_data:hire_date::DATE AS hire_date,
    raw_data:is_active::BOOLEAN AS is_active,
    _ingested_at,
    ROW_NUMBER() OVER (
      PARTITION BY raw_data:provider_id::STRING
      ORDER BY _ingested_at DESC
    ) AS rn
  FROM {{ source('landing', 'raw_facility_ops') }}
  WHERE raw_data:provider_id IS NOT NULL
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
  LEAD(_ingested_at) OVER (PARTITION BY provider_id ORDER BY _ingested_at) AS valid_to,
  IFF(rn = 1, TRUE, FALSE) AS is_current,
  DATEDIFF('year', hire_date, CURRENT_DATE()) AS years_of_service
FROM provider_data
