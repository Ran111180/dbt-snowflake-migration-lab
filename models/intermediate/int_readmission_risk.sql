{# int_readmission_risk: Complex window + date logic for 30-day readmission #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH encounters_ordered AS (
    SELECT
        patient_id,
        encounter_id,
        encounter_type,
        admit_datetime,
        discharge_datetime,
        discharge_disposition,
        total_hours,
        ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY admit_datetime) AS encounter_seq,
        LAG(discharge_datetime) OVER (PARTITION BY patient_id ORDER BY admit_datetime) AS prev_discharge,
        LAG(encounter_id) OVER (PARTITION BY patient_id ORDER BY admit_datetime) AS prev_encounter_id,
        LAG(discharge_disposition) OVER (PARTITION BY patient_id ORDER BY admit_datetime) AS prev_disposition,
        LEAD(admit_datetime) OVER (PARTITION BY patient_id ORDER BY admit_datetime) AS next_admit
    FROM {{ ref('stg_encounters') }}
    WHERE encounter_type IN ('Inpatient', 'Rehab', 'Observation')
)

SELECT
    *,
    DATEDIFF('day', prev_discharge, admit_datetime) AS days_since_last_discharge,
    IFF(DATEDIFF('day', prev_discharge, admit_datetime) <= 30, TRUE, FALSE) AS is_30_day_readmission,
    IFF(DATEDIFF('day', prev_discharge, admit_datetime) <= 7, TRUE, FALSE) AS is_7_day_readmission,
    IFF(next_admit IS NOT NULL AND DATEDIFF('day', discharge_datetime, next_admit) <= 30, TRUE, FALSE) AS will_readmit_30d,
    CASE
        WHEN DATEDIFF('day', prev_discharge, admit_datetime) <= 7 THEN 'Very High Risk'
        WHEN DATEDIFF('day', prev_discharge, admit_datetime) <= 14 THEN 'High Risk'
        WHEN DATEDIFF('day', prev_discharge, admit_datetime) <= 30 THEN 'Moderate Risk'
        ELSE 'Low Risk'
    END AS readmission_risk_level,
    COUNT(*) OVER (PARTITION BY patient_id) AS total_encounters
FROM encounters_ordered
