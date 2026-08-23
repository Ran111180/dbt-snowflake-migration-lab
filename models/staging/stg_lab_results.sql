{# stg_lab_results: LATERAL FLATTEN nested arrays, CASE, NVL, window LAG #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
    raw_data:patient_id::STRING AS patient_id,
    raw_data:order_id::STRING AS order_id,
    raw_data:test_panel::STRING AS test_panel,
    r.value:analyte::STRING AS analyte_name,
    r.value:value::FLOAT AS result_value,
    r.value:unit::STRING AS unit,
    r.value:ref_low::FLOAT AS reference_low,
    r.value:ref_high::FLOAT AS reference_high,
    NVL(r.value:flag::STRING, 'NORMAL') AS result_flag,
    CASE
        WHEN r.value:value::FLOAT < r.value:ref_low::FLOAT THEN 'Below Normal'
        WHEN r.value:value::FLOAT > r.value:ref_high::FLOAT THEN 'Above Normal'
        ELSE 'Normal'
    END AS interpretation,
    TRY_CAST(raw_data:collected_at::STRING AS TIMESTAMP_NTZ) AS collected_at,
    TRY_CAST(raw_data:resulted_at::STRING AS TIMESTAMP_NTZ) AS resulted_at,
    DATEDIFF('hour', TRY_CAST(raw_data:collected_at::STRING AS TIMESTAMP_NTZ), TRY_CAST(raw_data:resulted_at::STRING AS TIMESTAMP_NTZ)) AS turnaround_hours,
    raw_data:ordering_provider::STRING AS ordering_provider,
    raw_data:status::STRING AS result_status,
    raw_data:critical_flag::BOOLEAN AS is_critical,
    LAG(r.value:value::FLOAT) OVER (
        PARTITION BY raw_data:patient_id::STRING, r.value:analyte::STRING
        ORDER BY TRY_CAST(raw_data:collected_at::STRING AS TIMESTAMP_NTZ)
    ) AS previous_value,
    r.value:value::FLOAT - NVL(LAG(r.value:value::FLOAT) OVER (
        PARTITION BY raw_data:patient_id::STRING, r.value:analyte::STRING
        ORDER BY TRY_CAST(raw_data:collected_at::STRING AS TIMESTAMP_NTZ)
    ), r.value:value::FLOAT) AS value_change,
    _ingested_at
FROM {{ source('landing', 'raw_lab_results') }}
    , LATERAL FLATTEN(input => raw_data:results) AS r
