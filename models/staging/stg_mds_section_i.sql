{# stg_mds_section_i: FLATTEN Section I diagnoses from MDS assessment #}
{{ config(materialized='view', tags=['staging', 'mds']) }}

SELECT
    raw_data:patient_id::STRING AS patient_id,
    dx.value::STRING AS section_i_icd10,
    dx.index + 1 AS diagnosis_position,
    'Section_I' AS mds_section,
    raw_data:mds_assessment.nursing_tier::STRING AS nursing_tier,
    _ingested_at
FROM {{ source('landing', 'raw_patients') }}
    , LATERAL FLATTEN(input => raw_data:mds_assessment.section_i) AS dx
