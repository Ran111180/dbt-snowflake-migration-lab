{# adv_date_spine: GENERATOR + seq4() for date dimension #}
{{ config(materialized='table', tags=['advanced', 'utility']) }}

WITH date_range AS (
    SELECT
        DATEADD('day', SEQ4(), '2024-01-01'::DATE) AS date_day
    FROM TABLE(GENERATOR(ROWCOUNT => 730))
)

SELECT
    date_day,
    YEAR(date_day) AS year_num,
    QUARTER(date_day) AS quarter_num,
    MONTH(date_day) AS month_num,
    MONTHNAME(date_day) AS month_name,
    WEEK(date_day) AS week_num,
    DAYOFWEEK(date_day) AS day_of_week,
    DAYNAME(date_day) AS day_name,
    DAY(date_day) AS day_of_month,
    DAYOFYEAR(date_day) AS day_of_year,
    IFF(DAYOFWEEK(date_day) IN (0, 6), TRUE, FALSE) AS is_weekend,
    IFF(date_day = LAST_DAY(date_day), TRUE, FALSE) AS is_month_end,
    DATE_TRUNC('month', date_day) AS first_of_month,
    LAST_DAY(date_day) AS last_of_month,
    DATEDIFF('day', DATE_TRUNC('month', date_day), date_day) + 1 AS day_of_month_seq,
    {{ fiscal_quarter('date_day') }} AS fiscal_quarter,
    'FY' || IFF(MONTH(date_day) >= 7, YEAR(date_day) + 1, YEAR(date_day))::VARCHAR AS fiscal_year
FROM date_range
