{# adv_bitwise_flags: BITAND, BITOR, BITSHIFTLEFT for status encoding #}
{{ config(materialized='table', tags=['advanced', 'encoding']) }}

WITH patient_flags AS (
  SELECT
    patient_id,
    -- Encode conditions as bit flags
    BITOR(
      BITOR(
        IFF(diagnosis_count > 3, BITSHIFTLEFT(1, 0), 0),  -- bit 0: complex patient
        IFF(medication_count > 5, BITSHIFTLEFT(1, 1), 0)   -- bit 1: polypharmacy
      ),
      BITOR(
        IFF(age > 85, BITSHIFTLEFT(1, 2), 0),              -- bit 2: elderly
        IFF(length_of_stay > 30, BITSHIFTLEFT(1, 3), 0)    -- bit 3: long stay
      )
    ) AS risk_flags,
    diagnosis_count,
    medication_count,
    age,
    length_of_stay
  FROM {{ ref('stg_patients') }}
)
SELECT
  patient_id,
  risk_flags,
  -- Decode individual flags
  BITAND(risk_flags, 1) > 0 AS is_complex,
  BITAND(risk_flags, 2) > 0 AS has_polypharmacy,
  BITAND(risk_flags, 4) > 0 AS is_elderly,
  BITAND(risk_flags, 8) > 0 AS is_long_stay,
  -- Count active flags
  (IFF(BITAND(risk_flags, 1) > 0, 1, 0) +
   IFF(BITAND(risk_flags, 2) > 0, 1, 0) +
   IFF(BITAND(risk_flags, 4) > 0, 1, 0) +
   IFF(BITAND(risk_flags, 8) > 0, 1, 0)) AS active_risk_flags,
  CASE
    WHEN risk_flags >= 12 THEN 'CRITICAL'
    WHEN risk_flags >= 6 THEN 'HIGH'
    WHEN risk_flags >= 2 THEN 'MODERATE'
    ELSE 'LOW'
  END AS risk_tier,
  diagnosis_count,
  medication_count,
  age,
  length_of_stay
FROM patient_flags
