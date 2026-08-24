{# int_discharge_planning: DATEDIFF + conditional window for discharge readiness #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

SELECT
  patient_id,
  encounter_id,
  encounter_type,
  admit_datetime,
  discharge_datetime,
  DATEDIFF('day', admit_datetime, COALESCE(discharge_datetime, CURRENT_TIMESTAMP())) AS length_of_stay_days,
  discharge_disposition,
  -- Days remaining estimate based on encounter type avg
  AVG(length_of_stay_days) OVER (PARTITION BY encounter_type) AS type_avg_los,
  length_of_stay_days - AVG(length_of_stay_days) OVER (PARTITION BY encounter_type) AS days_over_avg,
  IFF(length_of_stay_days > AVG(length_of_stay_days) OVER (PARTITION BY encounter_type) * 1.5,
    'OVERDUE', 'ON_TRACK') AS discharge_status,
  NTILE(4) OVER (ORDER BY length_of_stay_days DESC) AS los_quartile,
  DATEDIFF('day',
    LAG(discharge_datetime) OVER (PARTITION BY patient_id ORDER BY admit_datetime),
    admit_datetime
  ) AS days_since_last_discharge,
  COUNT(*) OVER (PARTITION BY patient_id) AS total_encounters_for_patient
FROM {{ ref('stg_encounters') }}
