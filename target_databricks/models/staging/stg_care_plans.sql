{# stg_care_plans: VARIANT array of objects, LISTAGG #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(raw_data, '$.encounter_id') AS STRING) AS encounter_id,
  CAST(GET_JSON_OBJECT(f, '$.goal') AS STRING) AS care_goal,
  CAST(GET_JSON_OBJECT(f, '$.intervention') AS STRING) AS intervention,
  CAST(GET_JSON_OBJECT(f, '$.status') AS STRING) AS goal_status,
  CAST(GET_JSON_OBJECT(f, '$.priority') AS DECIMAL(38, 0)) AS priority_rank,
  DATE(TRY_TO_TIMESTAMP(CAST(GET_JSON_OBJECT(f, '$.target_date') AS STRING), 'yyyy-MM-dd')) AS target_date,
  f_pos + 1 AS goal_sequence,
  LISTAGG(CAST(GET_JSON_OBJECT(f, '$.intervention') AS STRING), '; ') WITHIN GROUP (ORDER BY
    CAST(GET_JSON_OBJECT(f, '$.priority') AS DECIMAL(38, 0)) NULLS LAST) OVER (PARTITION BY CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING)) AS all_interventions,
  _ingested_at
FROM {{ source('landing', 'raw_encounters') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.care_plan'), 'ARRAY<STRING>')) f_tbl AS f_pos, f
WHERE
  GET_JSON_OBJECT(f, '$.goal') IS NOT NULL