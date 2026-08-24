{# fct_provider_performance: UNPIVOT metrics for flexible reporting #}
{{ config(materialized='table', tags=['marts', 'providers']) }}

WITH base_metrics AS (
  SELECT
    facility_id,
    encounter_type,
    DATE_TRUNC('month', admit_datetime) AS month,
    COUNT(*)::FLOAT AS encounter_count,
    AVG(DATEDIFF('day', admit_datetime, COALESCE(discharge_datetime, CURRENT_TIMESTAMP())))::FLOAT AS avg_los
  FROM {{ ref('stg_encounters') }}
  GROUP BY facility_id, encounter_type, DATE_TRUNC('month', admit_datetime)
),
unpivoted AS (
  SELECT facility_id, encounter_type, month, metric_name, metric_value
  FROM base_metrics
    UNPIVOT(metric_value FOR metric_name IN (encounter_count, avg_los))
)
SELECT
  facility_id,
  encounter_type,
  month,
  metric_name,
  metric_value,
  SUM(metric_value) OVER (PARTITION BY facility_id, metric_name) AS facility_total,
  RATIO_TO_REPORT(metric_value) OVER (PARTITION BY facility_id, metric_name) AS pct_of_facility
FROM unpivoted
ORDER BY facility_id, month, metric_name
