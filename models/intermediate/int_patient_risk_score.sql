{# int_patient_risk_score: Multiple window functions, NTILE, CUME_DIST, PERCENT_RANK #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH patient_metrics AS (
    SELECT
        p.patient_id,
        p.age,
        p.diagnosis_count,
        p.medication_count,
        p.length_of_stay,
        p.bp_systolic,
        p.o2_saturation,
        p.pain_level
    FROM {{ ref('stg_patients') }} p
),

scored AS (
    SELECT
        patient_id,
        age,
        diagnosis_count,
        medication_count,
        length_of_stay,
        -- Composite risk score
        (CASE WHEN age > 85 THEN 3 WHEN age > 75 THEN 2 ELSE 1 END
         + CASE WHEN diagnosis_count > 4 THEN 3 WHEN diagnosis_count > 2 THEN 2 ELSE 1 END
         + CASE WHEN medication_count > 5 THEN 3 WHEN medication_count > 3 THEN 2 ELSE 1 END
         + CASE WHEN bp_systolic > 160 THEN 3 WHEN bp_systolic > 140 THEN 2 ELSE 0 END
         + CASE WHEN o2_saturation < 90 THEN 3 WHEN o2_saturation < 94 THEN 2 ELSE 0 END
         + CASE WHEN pain_level > 7 THEN 2 WHEN pain_level > 4 THEN 1 ELSE 0 END
        ) AS raw_risk_score,
        NTILE(4) OVER (ORDER BY 
            (CASE WHEN age > 85 THEN 3 WHEN age > 75 THEN 2 ELSE 1 END
             + diagnosis_count + medication_count)
        ) AS risk_quartile,
        PERCENT_RANK() OVER (ORDER BY length_of_stay) AS los_percentile,
        CUME_DIST() OVER (ORDER BY diagnosis_count) AS dx_cumulative_dist,
        ROW_NUMBER() OVER (ORDER BY 
            (CASE WHEN age > 85 THEN 3 ELSE 1 END + diagnosis_count + medication_count) DESC
        ) AS risk_rank
    FROM patient_metrics
)

SELECT
    *,
    CASE
        WHEN risk_quartile = 4 THEN 'Critical'
        WHEN risk_quartile = 3 THEN 'High'
        WHEN risk_quartile = 2 THEN 'Moderate'
        ELSE 'Low'
    END AS risk_category
FROM scored
