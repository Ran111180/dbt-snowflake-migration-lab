{# stg_procedures: Double LATERAL FLATTEN (encounters→procedures), REGEXP_SUBSTR #}
{{ config(materialized='view', tags=['staging', 'billing']) }}

SELECT
    raw_data:encounter_id::STRING AS encounter_id,
    raw_data:patient_id::STRING AS patient_id,
    p.value:code::STRING AS procedure_code,
    p.value:description::STRING AS procedure_description,
    p.value:units::INT AS units,
    p.value:charge::FLOAT AS charge_amount,
    p.value:performed_by::STRING AS performed_by,
    TRY_CAST(p.value:service_date::STRING AS DATE) AS service_date,
    p.index + 1 AS line_number,
    -- Use REGEXP to extract procedure category from code
    REGEXP_SUBSTR(p.value:code::STRING, '^[0-9]{2}') AS code_prefix,
    CASE
        WHEN REGEXP_LIKE(p.value:code::STRING, '^99[0-9]{3}$') THEN 'E&M'
        WHEN REGEXP_LIKE(p.value:code::STRING, '^97[0-9]{3}$') THEN 'Therapy'
        WHEN REGEXP_LIKE(p.value:code::STRING, '^[0-9]{5}$') THEN 'Procedure'
        ELSE 'Other'
    END AS procedure_category,
    raw_data:charges.total::FLOAT AS encounter_total_charges,
    RATIO_TO_REPORT(p.value:charge::FLOAT) OVER (
        PARTITION BY raw_data:encounter_id::STRING
    ) AS charge_pct_of_encounter,
    _ingested_at
FROM {{ source('landing', 'raw_encounters') }}
    , LATERAL FLATTEN(input => raw_data:procedures) AS p
