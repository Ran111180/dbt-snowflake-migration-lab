{# adv_date_spine: GENERATOR + seq4() for date dimension #}
{{ config(materialized='table', tags=['advanced', 'utility']) }}

WITH date_range AS (
  SELECT
    DATEADD(DAY, id, CAST('2024-01-01' AS DATE)) AS date_day
  FROM (SELECT EXPLODE(SEQUENCE(0, 729)) AS id)
)
SELECT
  date_day,
  YEAR(date_day) AS year_num,
  QUARTER(date_day) AS quarter_num,
  MONTH(date_day) AS month_num,
  DATE_FORMAT(date_day, 'MMM') AS month_name,
  WEEKOFYEAR(date_day) AS week_num,
  DAYOFWEEK(date_day) AS day_of_week,
  DATE_FORMAT(date_day, 'E') AS day_name,
  DAY(date_day) AS day_of_month,
  DAYOFYEAR(date_day) AS day_of_year,
  IF(DAYOFWEEK(date_day) IN (0, 6), TRUE, FALSE) AS is_weekend,
  IF(date_day = LAST_DAY(date_day), TRUE, FALSE) AS is_month_end,
  DATE_TRUNC('MONTH', date_day) AS first_of_month,
  LAST_DAY(date_day) AS last_of_month,
  DATEDIFF(DAY, DATE_TRUNC('MONTH', date_day), date_day) + 1 AS day_of_month_seq,
  CASE
    WHEN MONTH(date_day) >= 7
    THEN 'Q' || CAST(CEIL((
      MONTH(date_day) - 7 + 1
    ) / 3.0) AS DECIMAL(38, 0))
    ELSE 'Q' || CAST(CEIL((
      MONTH(date_day) + 12 - 7 + 1
    ) / 3.0) AS DECIMAL(38, 0))
  END AS fiscal_quarter,
  'FY' || CAST(IF(MONTH(date_day) >= 7, YEAR(date_day) + 1, YEAR(date_day)) AS STRING) AS fiscal_year
FROM date_range