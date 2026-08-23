{# int_medication_interactions: Self-join for drug pairs, ARRAY_AGG, LISTAGG #}
{{ config(materialized='table', tags=['intermediate', 'pharmacy']) }}

WITH meds AS (
    SELECT
        patient_id,
        medication_name,
        route,
        frequency,
        is_injectable,
        risk_category,
        start_date
    FROM {{ ref('stg_medications') }}
),

-- Self-join to find medication pairs per patient
med_pairs AS (
    SELECT
        a.patient_id,
        a.medication_name AS med_1,
        b.medication_name AS med_2,
        a.route AS route_1,
        b.route AS route_2,
        -- Known interaction rules
        CASE
            WHEN (a.medication_name = 'Enoxaparin' AND b.medication_name = 'Aspirin') THEN 'HIGH'
            WHEN (a.medication_name LIKE '%statin' AND b.medication_name LIKE '%fibrate') THEN 'HIGH'
            WHEN (a.route = 'IV' AND b.route = 'IV') THEN 'MODERATE'
            ELSE 'LOW'
        END AS interaction_risk
    FROM meds a
    JOIN meds b
        ON a.patient_id = b.patient_id
        AND a.medication_name < b.medication_name  -- avoid duplicates
),

patient_summary AS (
    SELECT
        patient_id,
        COUNT(*) AS total_medications,
        COUNT_IF(is_injectable) AS injectable_count,
        LISTAGG(DISTINCT medication_name, ', ') WITHIN GROUP (ORDER BY medication_name) AS all_medications,
        ARRAY_AGG(DISTINCT route) WITHIN GROUP (ORDER BY route) AS routes_array,
        MAX(CASE WHEN risk_category = 'High Risk' THEN 1 ELSE 0 END) AS has_high_risk_med
    FROM meds
    GROUP BY patient_id
)

SELECT
    ps.patient_id,
    ps.total_medications,
    ps.injectable_count,
    ps.all_medications,
    ps.routes_array,
    ps.has_high_risk_med,
    COUNT(mp.med_1) AS interaction_pair_count,
    COUNT_IF(mp.interaction_risk = 'HIGH') AS high_risk_interactions,
    IFF(ps.total_medications >= 5, TRUE, FALSE) AS is_polypharmacy
FROM patient_summary ps
LEFT JOIN med_pairs mp ON ps.patient_id = mp.patient_id
GROUP BY ps.patient_id, ps.total_medications, ps.injectable_count, 
         ps.all_medications, ps.routes_array, ps.has_high_risk_med
