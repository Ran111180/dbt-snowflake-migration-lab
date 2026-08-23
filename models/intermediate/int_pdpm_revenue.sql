{# int_pdpm_revenue: Complex CASE scoring, OBJECT_CONSTRUCT for JSON output #}
{{ config(materialized='table', tags=['intermediate', 'billing', 'pdpm']) }}

WITH base AS (
    SELECT
        patient_id,
        nursing_tier,
        nta_tier,
        pt_tier,
        ot_tier,
        slp_tier,
        nursing_score,
        nta_score
    FROM {{ ref('stg_mds_assessments') }}
),

-- PDPM rate calculation (simplified)
rated AS (
    SELECT
        patient_id,
        nursing_tier,
        nta_tier,
        pt_tier,
        ot_tier,
        slp_tier,
        -- Per-diem rates by component
        CASE nursing_tier
            WHEN 'ES3' THEN 225.50 WHEN 'ES2' THEN 198.30 
            WHEN 'HDE2' THEN 175.80 WHEN 'HDE1' THEN 155.20 ELSE 135.00
        END AS nursing_rate,
        CASE nta_tier
            WHEN 'A' THEN 890.00 WHEN 'B' THEN 650.00 
            WHEN 'C' THEN 450.00 ELSE 280.00
        END AS nta_rate,
        CASE pt_tier
            WHEN 'RU' THEN 175.00 WHEN 'RV' THEN 145.00 ELSE 95.00
        END AS pt_rate,
        CASE ot_tier
            WHEN 'RU' THEN 165.00 WHEN 'RV' THEN 135.00 ELSE 90.00
        END AS ot_rate,
        CASE slp_tier
            WHEN 'SA' THEN 55.00 WHEN 'SB' THEN 45.00 ELSE 35.00
        END AS slp_rate
    FROM base
)

SELECT
    patient_id,
    nursing_tier,
    nta_tier,
    pt_tier,
    ot_tier,
    slp_tier,
    nursing_rate,
    nta_rate,
    pt_rate,
    ot_rate,
    slp_rate,
    nursing_rate + nta_rate + pt_rate + ot_rate + slp_rate AS total_per_diem,
    (nursing_rate + nta_rate + pt_rate + ot_rate + slp_rate) * 30 AS projected_monthly_revenue,
    -- JSON summary
    OBJECT_CONSTRUCT(
        'nursing', OBJECT_CONSTRUCT('tier', nursing_tier, 'rate', nursing_rate),
        'nta', OBJECT_CONSTRUCT('tier', nta_tier, 'rate', nta_rate),
        'pt', OBJECT_CONSTRUCT('tier', pt_tier, 'rate', pt_rate),
        'ot', OBJECT_CONSTRUCT('tier', ot_tier, 'rate', ot_rate),
        'slp', OBJECT_CONSTRUCT('tier', slp_tier, 'rate', slp_rate),
        'total', nursing_rate + nta_rate + pt_rate + ot_rate + slp_rate
    ) AS pdpm_detail_json,
    RATIO_TO_REPORT(nursing_rate + nta_rate + pt_rate + ot_rate + slp_rate) OVER () AS revenue_share
FROM rated
