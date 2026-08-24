{# stg_vital_alerts: Nested IFF 4-deep, NVL2, DECODE #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  raw_data:vitals.heart_rate::NUMBER AS heart_rate,
  raw_data:vitals.systolic_bp::NUMBER AS systolic_bp,
  raw_data:vitals.diastolic_bp::NUMBER AS diastolic_bp,
  raw_data:vitals.temperature::FLOAT AS temperature,
  raw_data:vitals.o2_sat::NUMBER AS o2_saturation,
  -- Nested IFF 4-deep for alert severity
  IFF(raw_data:vitals.heart_rate::NUMBER > 150,
    'CRITICAL',
    IFF(raw_data:vitals.heart_rate::NUMBER > 120,
      'HIGH',
      IFF(raw_data:vitals.heart_rate::NUMBER > 100,
        'MODERATE',
        IFF(raw_data:vitals.heart_rate::NUMBER < 50, 'LOW_HR', 'NORMAL')
      )
    )
  ) AS hr_alert_level,
  -- NVL2: if value exists use it, otherwise default
  NVL2(raw_data:vitals.o2_sat, 
    IFF(raw_data:vitals.o2_sat::NUMBER < 90, 'HYPOXIC', 'NORMAL'),
    'NOT_MEASURED'
  ) AS o2_status,
  -- DECODE for categorical mapping
  DECODE(raw_data:vitals.position::STRING,
    'supine', 'Lying Down',
    'sitting', 'Seated',
    'standing', 'Upright',
    'Unknown'
  ) AS patient_position,
  _ingested_at
FROM {{ source('landing', 'raw_patients') }}
WHERE raw_data:vitals IS NOT NULL
