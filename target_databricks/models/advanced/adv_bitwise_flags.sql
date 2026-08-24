{# adv_bitwise_flags: BITAND, BITOR, BITSHIFTLEFT for status encoding #}
{{ config(materialized='table', tags=['advanced', 'encoding']) }}

WITH patient_flags AS (
  SELECT
    patient_id,
    IF(diagnosis_count > 3, SHIFTLEFT(1, 0), 0) /* bit 0: complex patient */ | IF(medication_count > 5, SHIFTLEFT(1, 1), 0) /* bit 1: polypharmacy */ | IF(age > 85, SHIFTLEFT(1, 2), 0) /* bit 2: elderly */ | IF(length_of_stay > 30, SHIFTLEFT(1, 3), 0) /* bit 3: long stay */ AS risk_flags, /* Encode conditions as bit flags */
    diagnosis_count,
    medication_count,
    age,
    length_of_stay
  FROM {{ ref('stg_patients') }}
)
SELECT
  patient_id,
  risk_flags,
  risk_flags & /* Decode individual flags */ 1 > 0 AS is_complex,
  risk_flags & 2 > 0 AS has_polypharmacy,
  risk_flags & 4 > 0 AS is_elderly,
  risk_flags & 8 > 0 AS is_long_stay,
  (
    IF(risk_flags & 1 > 0, 1, 0) + IF(risk_flags & 2 > 0, 1, 0) + IF(risk_flags & 4 > 0, 1, 0) + IF(risk_flags & 8 > 0, 1, 0)
  ) AS active_risk_flags, /* Count active flags */
  CASE
    WHEN risk_flags >= 12
    THEN 'CRITICAL'
    WHEN risk_flags >= 6
    THEN 'HIGH'
    WHEN risk_flags >= 2
    THEN 'MODERATE'
    ELSE 'LOW'
  END AS risk_tier,
  diagnosis_count,
  medication_count,
  age,
  length_of_stay
FROM patient_flags