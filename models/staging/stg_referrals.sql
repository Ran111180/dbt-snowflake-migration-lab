{# stg_referrals: VARIANT nested object, window functions #}
{{ config(materialized='view', tags=['staging', 'clinical']) }}

SELECT
  raw_data:patient_id::STRING AS patient_id,
  raw_data:encounter_id::STRING AS encounter_id,
  raw_data:referral.to_provider::STRING AS referred_to,
  raw_data:referral.from_provider::STRING AS referred_from,
  raw_data:referral.specialty::STRING AS referral_specialty,
  raw_data:referral.reason::STRING AS referral_reason,
  raw_data:referral.priority::STRING AS priority,
  TRY_TO_DATE(raw_data:referral.referral_date::STRING) AS referral_date,
  TRY_TO_DATE(raw_data:referral.completed_date::STRING) AS completed_date,
  DATEDIFF('day',
    TRY_TO_DATE(raw_data:referral.referral_date::STRING),
    COALESCE(TRY_TO_DATE(raw_data:referral.completed_date::STRING), CURRENT_DATE())
  ) AS days_to_complete,
  ROW_NUMBER() OVER (
    PARTITION BY raw_data:patient_id::STRING
    ORDER BY TRY_TO_DATE(raw_data:referral.referral_date::STRING) DESC NULLS LAST
  ) AS referral_recency_rank,
  _ingested_at
FROM {{ source('landing', 'raw_encounters') }}
WHERE raw_data:referral IS NOT NULL
