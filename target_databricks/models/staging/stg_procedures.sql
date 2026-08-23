{# stg_procedures: Double LATERAL FLATTEN (encounters→procedures), REGEXP_SUBSTR #}
{{ config(materialized='view', tags=['staging', 'billing']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING) AS encounter_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(p, '$.code') AS STRING) AS procedure_code,
  CAST(GET_JSON_OBJECT(p, '$.description') AS STRING) AS procedure_description,
  CAST(GET_JSON_OBJECT(p, '$.units') AS DECIMAL(38, 0)) AS units,
  CAST(GET_JSON_OBJECT(p, '$.charge') AS DOUBLE) AS charge_amount,
  CAST(GET_JSON_OBJECT(p, '$.performed_by') AS STRING) AS performed_by,
  TRY_CAST(CAST(GET_JSON_OBJECT(p, '$.service_date') AS STRING) AS DATE) AS service_date,
  p_pos + 1 AS line_number,
  REGEXP_EXTRACT(CAST(GET_JSON_OBJECT(p, '$.code') AS STRING), '^[0-9]{2}', 0) AS code_prefix, /* Use REGEXP to extract procedure category from code */
  CASE
    WHEN REGEXP_LIKE(CAST(GET_JSON_OBJECT(p, '$.code') AS STRING), '^99[0-9]{3}$')
    THEN 'E&M'
    WHEN REGEXP_LIKE(CAST(GET_JSON_OBJECT(p, '$.code') AS STRING), '^97[0-9]{3}$')
    THEN 'Therapy'
    WHEN REGEXP_LIKE(CAST(GET_JSON_OBJECT(p, '$.code') AS STRING), '^[0-9]{5}$')
    THEN 'Procedure'
    ELSE 'Other'
  END AS procedure_category,
  CAST(GET_JSON_OBJECT(raw_data, '$.charges.total') AS DOUBLE) AS encounter_total_charges,
  (CAST(GET_JSON_OBJECT(p, '$.charge') AS DOUBLE)) / SUM(CAST(GET_JSON_OBJECT(p, '$.charge') AS DOUBLE)) OVER (PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING)) AS charge_pct_of_encounter,
  _ingested_at
FROM {{ source('landing', 'raw_encounters') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.procedures'), 'ARRAY<STRING>')) p_tbl AS p_pos, p