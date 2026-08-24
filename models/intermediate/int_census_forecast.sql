{# int_census_forecast: GENERATOR date series + moving average forecast #}
{{ config(materialized='table', tags=['intermediate', 'operations']) }}

WITH date_series AS (
  SELECT
    DATEADD('day', SEQ4(), DATEADD('day', -90, CURRENT_DATE())) AS forecast_date
  FROM TABLE(GENERATOR(ROWCOUNT => 120))  -- 90 days back + 30 forward
),
daily_census AS (
  SELECT
    facility_id,
    admit_date AS census_date,
    COUNT(*) AS patient_count
  FROM {{ ref('stg_patients') }}
  GROUP BY facility_id, admit_date
),
enriched AS (
  SELECT
    f.facility_id,
    ds.forecast_date,
    COALESCE(dc.patient_count, 0) AS actual_count,
    AVG(COALESCE(dc.patient_count, 0)) OVER (
      PARTITION BY f.facility_id
      ORDER BY ds.forecast_date
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7d,
    AVG(COALESCE(dc.patient_count, 0)) OVER (
      PARTITION BY f.facility_id
      ORDER BY ds.forecast_date
      ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS moving_avg_30d
  FROM date_series ds
  CROSS JOIN (SELECT DISTINCT facility_id FROM daily_census) f
  LEFT JOIN daily_census dc ON dc.facility_id = f.facility_id AND dc.census_date = ds.forecast_date
)
SELECT
  facility_id,
  forecast_date,
  actual_count,
  ROUND(moving_avg_7d, 1) AS forecast_7d,
  ROUND(moving_avg_30d, 1) AS forecast_30d,
  IFF(forecast_date > CURRENT_DATE(), TRUE, FALSE) AS is_forecast,
  actual_count - ROUND(moving_avg_7d, 0) AS variance_from_forecast
FROM enriched
WHERE facility_id IS NOT NULL
