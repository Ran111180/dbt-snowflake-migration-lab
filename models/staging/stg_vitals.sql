{# stg_vitals: VARIANT vitals extraction, CASE expressions, clinical thresholds #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
    raw_data:patient_id::STRING AS patient_id,
    raw_data:vitals.bp_systolic::INT AS bp_systolic,
    raw_data:vitals.bp_diastolic::INT AS bp_diastolic,
    raw_data:vitals.heart_rate::INT AS heart_rate,
    raw_data:vitals.temperature::FLOAT AS temperature_f,
    raw_data:vitals.weight_lbs::FLOAT AS weight_lbs,
    raw_data:vitals.o2_saturation::INT AS o2_saturation,
    raw_data:vitals.pain_level::INT AS pain_level,
    TRY_CAST(raw_data:vitals.recorded_at::STRING AS TIMESTAMP_NTZ) AS recorded_at,
    -- Clinical classifications
    CASE
        WHEN raw_data:vitals.bp_systolic::INT >= 180 OR raw_data:vitals.bp_diastolic::INT >= 120 THEN 'Hypertensive Crisis'
        WHEN raw_data:vitals.bp_systolic::INT >= 140 OR raw_data:vitals.bp_diastolic::INT >= 90 THEN 'Stage 2 HTN'
        WHEN raw_data:vitals.bp_systolic::INT >= 130 OR raw_data:vitals.bp_diastolic::INT >= 80 THEN 'Stage 1 HTN'
        WHEN raw_data:vitals.bp_systolic::INT >= 120 THEN 'Elevated'
        ELSE 'Normal'
    END AS bp_classification,
    IFF(raw_data:vitals.heart_rate::INT < 60, 'Bradycardia',
        IFF(raw_data:vitals.heart_rate::INT > 100, 'Tachycardia', 'Normal')) AS hr_classification,
    IFF(raw_data:vitals.temperature::FLOAT > 100.4, TRUE, FALSE) AS has_fever,
    IFF(raw_data:vitals.o2_saturation::INT < 90, 'Critical',
        IFF(raw_data:vitals.o2_saturation::INT < 94, 'Low', 'Normal')) AS o2_classification,
    _ingested_at
FROM {{ source('landing', 'raw_patients') }}
