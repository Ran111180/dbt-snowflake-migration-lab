{# adv_unpivot_metrics: UNPIVOT patient metrics for flexible reporting #}
{{ config(materialized='table', tags=['advanced', 'reporting']) }}

WITH patient_metrics AS (
  SELECT
    patient_id,
    age,
    diagnosis_count,
    medication_count,
    length_of_stay
  FROM {{ ref('stg_patients') }}
)
SELECT
  patient_id,
  metric_name,
  metric_value,
  PERCENT_RANK() OVER (PARTITION BY metric_name ORDER BY metric_value) AS percentile_rank,
  NTILE(10) OVER (PARTITION BY metric_name ORDER BY metric_value) AS decile,
  AVG(metric_value) OVER (PARTITION BY metric_name) AS population_avg,
  metric_value - AVG(metric_value) OVER (PARTITION BY metric_name) AS deviation_from_avg
FROM patient_metrics
  UNPIVOT(metric_value FOR metric_name IN (age, diagnosis_count, medication_count, length_of_stay))
