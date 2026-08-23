{# fct_clinical_events: Fact table combining alerts and events #}
{{ config(
    materialized='incremental',
    unique_key='event_key',
    incremental_strategy='merge',
    tags=['marts', 'gold', 'clinical']
) }}

SELECT
    {{ surrogate_key(['alert_type', 'patient_id', 'alert_timestamp']) }} AS event_key,
    patient_id,
    alert_type AS event_type,
    alert_message AS event_description,
    priority AS severity_level,
    alert_timestamp AS event_datetime,
    DATE_TRUNC('day', alert_timestamp) AS event_date,
    DATE_TRUNC('hour', alert_timestamp) AS event_hour,
    EXTRACT(HOUR FROM alert_timestamp) AS hour_of_day,
    DAYOFWEEK(alert_timestamp::DATE) AS day_of_week,
    alert_rank,
    total_patient_alerts,
    most_critical_alert,
    CURRENT_TIMESTAMP() AS _last_updated
FROM {{ ref('int_clinical_alerts') }}
{% if is_incremental() %}
WHERE alert_timestamp > (SELECT MAX(_last_updated) FROM {{ this }})
{% endif %}
