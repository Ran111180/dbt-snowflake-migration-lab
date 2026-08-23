{# int_facility_census: GROUP BY with PIVOT pattern, conditional aggregation, MEDIAN #}
{{ config(materialized='table', tags=['intermediate', 'operations']) }}

WITH daily_census AS (
    SELECT
        facility_id,
        admit_date,
        COUNT(*) AS total_patients,
        COUNT_IF(is_current_resident) AS active_count,
        COUNT_IF(NOT is_current_resident) AS discharged_count,
        MEDIAN(length_of_stay) AS median_los,
        AVG(length_of_stay) AS avg_los,
        MAX(length_of_stay) AS max_los,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY length_of_stay) AS p75_los,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY length_of_stay) AS p90_los,
        COUNT_IF(age > 85) AS very_elderly_count,
        COUNT_IF(diagnosis_count > 3) AS complex_patient_count,
        AVG(bp_systolic) AS avg_bp_systolic,
        AVG(o2_saturation) AS avg_o2_sat
    FROM {{ ref('stg_patients') }}
    GROUP BY facility_id, admit_date
)

SELECT
    facility_id,
    admit_date,
    total_patients,
    active_count,
    discharged_count,
    ROUND(median_los, 1) AS median_los,
    ROUND(avg_los, 1) AS avg_los,
    max_los,
    ROUND(p75_los, 1) AS p75_los,
    ROUND(p90_los, 1) AS p90_los,
    very_elderly_count,
    complex_patient_count,
    ROUND(avg_bp_systolic, 0) AS avg_bp_systolic,
    ROUND(avg_o2_sat, 0) AS avg_o2_sat,
    -- Utilization metrics
    DIV0NULL(active_count, total_patients) AS active_rate,
    DIV0NULL(complex_patient_count, total_patients) AS complexity_ratio,
    -- Trend vs previous admit date
    LAG(total_patients) OVER (PARTITION BY facility_id ORDER BY admit_date) AS prev_day_total,
    total_patients - NVL(LAG(total_patients) OVER (PARTITION BY facility_id ORDER BY admit_date), total_patients) AS daily_change
FROM daily_census
