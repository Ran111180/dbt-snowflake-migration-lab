{# int_time_series_gaps: GENERATOR + DATEADD for gap detection in vitals #}
{{ config(materialized='table', tags=['intermediate', 'clinical']) }}

WITH date_spine AS (
  SELECT
    DATEADD(HOUR, id, DATEADD(DAY, -7, CURRENT_TIMESTAMP())) AS expected_time
  FROM (SELECT EXPLODE(SEQUENCE(0, 167)) AS id)
), actual_readings AS (
  SELECT
    patient_id,
    DATE_TRUNC('HOUR', _ingested_at) AS reading_hour,
    COUNT(*) AS reading_count,
    AVG(heart_rate) AS avg_hr
  FROM {{ ref('stg_vitals') }}
  WHERE
    _ingested_at >= DATEADD(DAY, -7, CURRENT_DATE())
  GROUP BY
    patient_id,
    DATE_TRUNC('HOUR', _ingested_at)
), patient_gaps AS (
  SELECT
    p.patient_id,
    ds.expected_time,
    ar.reading_count,
    ar.avg_hr,
    IF(ar.reading_hour IS NULL, TRUE, FALSE) AS is_gap,
    LAG(ar.reading_hour) OVER (PARTITION BY p.patient_id ORDER BY ds.expected_time ASC NULLS LAST) AS prev_reading,
    DATEDIFF(
      HOUR,
      LAG(ar.reading_hour) OVER (PARTITION BY p.patient_id ORDER BY ds.expected_time ASC NULLS LAST),
      ds.expected_time
    ) AS hours_since_last
  FROM date_spine AS ds
  CROSS JOIN (
    SELECT DISTINCT
      patient_id
    FROM actual_readings
  ) AS p
  LEFT JOIN actual_readings AS ar
    ON ar.patient_id = p.patient_id AND ar.reading_hour = ds.expected_time
)
SELECT
  patient_id,
  expected_time,
  is_gap,
  hours_since_last,
  COALESCE(reading_count, 0) AS readings_in_window,
  avg_hr,
  IF(hours_since_last > 4, 'CRITICAL_GAP', IF(hours_since_last > 2, 'WARNING_GAP', 'OK')) AS gap_severity,
  SUM(IF(is_gap, 1, 0)) OVER (
    PARTITION BY patient_id
    ORDER BY expected_time ASC NULLS LAST
    ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
  ) AS consecutive_gaps
FROM patient_gaps