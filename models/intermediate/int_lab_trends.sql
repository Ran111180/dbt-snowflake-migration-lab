{# int_lab_trends: LAG/LEAD window functions, moving averages, QUALIFY for dedup #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH lab_ordered AS (
    SELECT
        patient_id,
        analyte_name,
        result_value,
        reference_low,
        reference_high,
        result_flag,
        collected_at,
        ROW_NUMBER() OVER (PARTITION BY patient_id, analyte_name ORDER BY collected_at) AS result_seq,
        LAG(result_value, 1) OVER (PARTITION BY patient_id, analyte_name ORDER BY collected_at) AS prev_value,
        LEAD(result_value, 1) OVER (PARTITION BY patient_id, analyte_name ORDER BY collected_at) AS next_value,
        AVG(result_value) OVER (
            PARTITION BY patient_id, analyte_name
            ORDER BY collected_at
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg_3,
        MIN(result_value) OVER (PARTITION BY patient_id, analyte_name) AS min_value,
        MAX(result_value) OVER (PARTITION BY patient_id, analyte_name) AS max_value,
        COUNT(*) OVER (PARTITION BY patient_id, analyte_name) AS total_readings
    FROM {{ ref('stg_lab_results') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY patient_id, analyte_name, DATE_TRUNC('day', collected_at)
        ORDER BY collected_at DESC
    ) = 1
)

SELECT
    *,
    result_value - NVL(prev_value, result_value) AS change_from_prev,
    IFF(prev_value IS NOT NULL, 
        DIV0NULL((result_value - prev_value), ABS(prev_value)) * 100, 
        0) AS pct_change,
    IFF(result_value < reference_low OR result_value > reference_high, TRUE, FALSE) AS is_abnormal,
    CASE
        WHEN result_value < reference_low AND NVL(prev_value, result_value) >= reference_low THEN 'NEW_LOW'
        WHEN result_value > reference_high AND NVL(prev_value, result_value) <= reference_high THEN 'NEW_HIGH'
        WHEN result_value BETWEEN reference_low AND reference_high AND (NVL(prev_value, 0) < reference_low OR NVL(prev_value, 999) > reference_high) THEN 'NORMALIZED'
        ELSE 'STABLE'
    END AS trend_status
FROM lab_ordered
