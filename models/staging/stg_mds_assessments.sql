{# stg_mds_assessments: Nested VARIANT object access, ARRAY_TO_STRING #}
{{ config(materialized='view', tags=['staging', 'clinical', 'mds']) }}

SELECT
    raw_data:patient_id::STRING AS patient_id,
    raw_data:mds_assessment.nursing_tier::STRING AS nursing_tier,
    raw_data:mds_assessment.nta_tier::STRING AS nta_tier,
    raw_data:mds_assessment.pt_tier::STRING AS pt_tier,
    raw_data:mds_assessment.ot_tier::STRING AS ot_tier,
    raw_data:mds_assessment.slp_tier::STRING AS slp_tier,
    ARRAY_SIZE(raw_data:mds_assessment.section_i) AS section_i_count,
    ARRAY_SIZE(raw_data:mds_assessment.section_o) AS section_o_count,
    ARRAY_TO_STRING(raw_data:mds_assessment.section_i, ', ') AS section_i_codes,
    ARRAY_TO_STRING(raw_data:mds_assessment.section_o, ', ') AS section_o_services,
    -- PDPM component scoring
    CASE raw_data:mds_assessment.nursing_tier::STRING
        WHEN 'ES3' THEN 5 WHEN 'ES2' THEN 4 WHEN 'HDE2' THEN 3 WHEN 'HDE1' THEN 2 ELSE 1
    END AS nursing_score,
    CASE raw_data:mds_assessment.nta_tier::STRING
        WHEN 'A' THEN 4 WHEN 'B' THEN 3 WHEN 'C' THEN 2 ELSE 1
    END AS nta_score,
    _ingested_at
FROM {{ source('landing', 'raw_patients') }}
