{# int_medication_adherence: LAG + DATEDIFF for gap analysis #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH med_timeline AS (
  SELECT
    patient_id,
    medication_name,
    start_date,
    route,
    ROW_NUMBER() OVER (PARTITION BY patient_id, medication_name ORDER BY start_date) AS fill_number,
    LAG(start_date) OVER (PARTITION BY patient_id, medication_name ORDER BY start_date) AS prev_fill_date,
    LEAD(start_date) OVER (PARTITION BY patient_id, medication_name ORDER BY start_date) AS next_fill_date
  FROM {{ ref('stg_medications') }}
)
SELECT
  patient_id,
  medication_name,
  start_date,
  fill_number,
  prev_fill_date,
  DATEDIFF('day', prev_fill_date, start_date) AS days_between_fills,
  IFF(DATEDIFF('day', prev_fill_date, start_date) > 30, TRUE, FALSE) AS is_gap,
  IFF(DATEDIFF('day', prev_fill_date, start_date) > 90, TRUE, FALSE) AS is_lapse,
  -- Adherence rate: % of expected fills received
  COUNT(*) OVER (PARTITION BY patient_id, medication_name) AS total_fills,
  CASE
    WHEN DATEDIFF('day', prev_fill_date, start_date) IS NULL THEN 'FIRST_FILL'
    WHEN DATEDIFF('day', prev_fill_date, start_date) <= 35 THEN 'ADHERENT'
    WHEN DATEDIFF('day', prev_fill_date, start_date) <= 90 THEN 'PARTIAL'
    ELSE 'NON_ADHERENT'
  END AS adherence_status
FROM med_timeline
