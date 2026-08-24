{# int_patient_journey: Multi-join + window for patient timeline #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

SELECT
  p.patient_id,
  p.full_name AS patient_name,
  e.encounter_id,
  e.encounter_type,
  e.admit_datetime,
  e.discharge_datetime,
  DATEDIFF(DAY, e.admit_datetime, COALESCE(e.discharge_datetime, CURRENT_TIMESTAMP())) AS length_of_stay_days,
  ROW_NUMBER() OVER (PARTITION BY p.patient_id ORDER BY e.admit_datetime ASC NULLS LAST) AS visit_number,
  LAG(e.discharge_datetime) OVER (PARTITION BY p.patient_id ORDER BY e.admit_datetime ASC NULLS LAST) AS prev_discharge,
  DATEDIFF(
    DAY,
    LAG(e.discharge_datetime) OVER (PARTITION BY p.patient_id ORDER BY e.admit_datetime ASC NULLS LAST),
    e.admit_datetime
  ) AS days_between_visits,
  COUNT(*) OVER (PARTITION BY p.patient_id) AS total_visits,
  FIRST_VALUE(e.encounter_type) OVER (
    PARTITION BY p.patient_id
    ORDER BY e.admit_datetime ASC NULLS LAST
  ) AS first_visit_type
FROM {{ ref('stg_patients') }} AS p
JOIN {{ ref('stg_encounters') }} AS e
  ON p.patient_id = e.patient_id