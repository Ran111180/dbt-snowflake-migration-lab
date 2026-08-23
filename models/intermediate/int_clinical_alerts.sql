{# int_clinical_alerts: UNION ALL pattern, priority scoring, DENSE_RANK #}
{{ config(materialized='table', tags=['intermediate', 'clinical', 'alerts']) }}

WITH vital_alerts AS (
    SELECT
        patient_id,
        'VITAL_ALERT' AS alert_type,
        CASE bp_classification
            WHEN 'Hypertensive Crisis' THEN 'Critical: BP ' || bp_systolic || '/' || bp_diastolic
            WHEN 'Stage 2 HTN' THEN 'High: BP ' || bp_systolic || '/' || bp_diastolic
            ELSE NULL
        END AS alert_message,
        CASE bp_classification
            WHEN 'Hypertensive Crisis' THEN 1
            WHEN 'Stage 2 HTN' THEN 2
            ELSE 3
        END AS priority,
        _ingested_at AS alert_timestamp
    FROM {{ ref('stg_vitals') }}
    WHERE bp_classification IN ('Hypertensive Crisis', 'Stage 2 HTN')
        OR o2_classification = 'Critical'
        OR has_fever = TRUE
),

lab_alerts AS (
    SELECT
        patient_id,
        'LAB_ALERT' AS alert_type,
        'Abnormal ' || analyte_name || ': ' || result_value || ' ' || unit || ' (' || result_flag || ')' AS alert_message,
        CASE result_flag
            WHEN 'LOW' THEN 2
            WHEN 'HIGH' THEN 2
            ELSE 3
        END AS priority,
        collected_at AS alert_timestamp
    FROM {{ ref('stg_lab_results') }}
    WHERE is_critical = TRUE OR result_flag IN ('LOW', 'HIGH')
),

event_alerts AS (
    SELECT
        patient_id,
        'FACILITY_EVENT' AS alert_type,
        event_type || ' at ' || full_location AS alert_message,
        CASE severity
            WHEN 'Critical' THEN 1
            WHEN 'High' THEN 2
            ELSE 3
        END AS priority,
        event_timestamp AS alert_timestamp
    FROM {{ ref('stg_facility_events') }}
    WHERE severity IN ('Critical', 'High') AND patient_id IS NOT NULL
),

all_alerts AS (
    SELECT * FROM vital_alerts WHERE alert_message IS NOT NULL
    UNION ALL
    SELECT * FROM lab_alerts
    UNION ALL
    SELECT * FROM event_alerts
)

SELECT
    *,
    DENSE_RANK() OVER (PARTITION BY patient_id ORDER BY priority, alert_timestamp DESC) AS alert_rank,
    COUNT(*) OVER (PARTITION BY patient_id) AS total_patient_alerts,
    FIRST_VALUE(alert_message) OVER (PARTITION BY patient_id ORDER BY priority, alert_timestamp DESC) AS most_critical_alert
FROM all_alerts
