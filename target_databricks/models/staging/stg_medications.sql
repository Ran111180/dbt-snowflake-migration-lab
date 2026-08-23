{# stg_medications: LATERAL FLATTEN, DECODE, IFF, LISTAGG #}
{{ config(materialized='view', tags=['staging', 'pharmacy']) }}

SELECT
  CAST(GET_JSON_OBJECT(raw_data, '$.patient_id') AS STRING) AS patient_id,
  CAST(GET_JSON_OBJECT(f, '$.name') AS STRING) AS medication_name,
  CAST(GET_JSON_OBJECT(f, '$.dose') AS STRING) AS dose,
  CAST(GET_JSON_OBJECT(f, '$.route') AS STRING) AS route,
  CAST(GET_JSON_OBJECT(f, '$.frequency') AS STRING) AS frequency,
  TRY_CAST(CAST(GET_JSON_OBJECT(f, '$.start_date') AS STRING) AS DATE) AS start_date,
  CAST(GET_JSON_OBJECT(f, '$.prescriber') AS STRING) AS prescriber_id,
  f_pos + 1 AS medication_sequence,
  DECODE(
    CAST(GET_JSON_OBJECT(f, '$.route') AS STRING),
    'PO',
    'Oral',
    'IV',
    'Intravenous',
    'SubQ',
    'Subcutaneous',
    'IM',
    'Intramuscular',
    'PR',
    'Rectal',
    'TOP',
    'Topical',
    'Other'
  ) AS route_description,
  IF(CAST(GET_JSON_OBJECT(f, '$.route') AS STRING) IN ('IV', 'SubQ', 'IM'), TRUE, FALSE) AS is_injectable,
  IF(
    CAST(GET_JSON_OBJECT(f, '$.route') AS STRING) = 'IV',
    'High Risk',
    IF(CAST(GET_JSON_OBJECT(f, '$.route') AS STRING) IN ('SubQ', 'IM'), 'Moderate Risk', 'Standard')
  ) AS risk_category,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
  LATERAL VIEW POSEXPLODE(FROM_JSON(GET_JSON_OBJECT(raw_data, '$.medications'), 'ARRAY<STRING>')) f_tbl AS f_pos, f