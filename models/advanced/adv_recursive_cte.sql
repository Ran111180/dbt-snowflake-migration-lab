{# adv_recursive_cte: Recursive CTE for org hierarchy / day generation #}
{{ config(materialized='table', tags=['advanced', 'recursive']) }}

-- Generate a 30-day lookback using recursive CTE
WITH RECURSIVE date_series (day_date, day_num) AS (
    -- Anchor
    SELECT CURRENT_DATE() AS day_date, 1 AS day_num
    UNION ALL
    -- Recursive
    SELECT DATEADD('day', -1, day_date), day_num + 1
    FROM date_series
    WHERE day_num < {{ var('lookback_days') }}
),

-- Join with actual events per day
daily_events AS (
    SELECT
        ds.day_date,
        ds.day_num AS days_ago,
        fe.facility_id,
        COUNT(fe.event_id) AS event_count,
        COUNT_IF(fe.severity = 'Critical') AS critical_count,
        COUNT_IF(NOT fe.is_resolved) AS unresolved_count
    FROM date_series ds
    LEFT JOIN {{ ref('stg_facility_events') }} fe
        ON DATE_TRUNC('day', fe.event_timestamp) = ds.day_date
    GROUP BY ds.day_date, ds.day_num, fe.facility_id
)

SELECT
    day_date,
    days_ago,
    facility_id,
    NVL(event_count, 0) AS event_count,
    NVL(critical_count, 0) AS critical_count,
    NVL(unresolved_count, 0) AS unresolved_count,
    AVG(NVL(event_count, 0)) OVER (
        PARTITION BY facility_id
        ORDER BY day_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7d_avg
FROM daily_events
WHERE facility_id IS NOT NULL
ORDER BY facility_id, day_date DESC
