{# stg_mds_section_o: FLATTEN Section O treatments, IFF pattern matching #}
{{ config(materialized='view', tags=['staging', 'mds']) }}

SELECT
    raw_data:patient_id::STRING AS patient_id,
    tx.value::STRING AS section_o_service,
    tx.index + 1 AS service_position,
    'Section_O' AS mds_section,
    IFF(tx.value::STRING LIKE '%injectable%', TRUE, FALSE) AS is_injectable,
    IFF(tx.value::STRING LIKE '%iv%' OR tx.value::STRING LIKE '%IV%', TRUE, FALSE) AS is_iv_service,
    IFF(tx.value::STRING LIKE '%therapy%', TRUE, FALSE) AS is_therapy,
    REGEXP_SUBSTR(tx.value::STRING, 'O[0-9]{4}') AS service_code,
    _ingested_at
FROM {{ source('landing', 'raw_patients') }}
    , LATERAL FLATTEN(input => raw_data:mds_assessment.section_o) AS tx
