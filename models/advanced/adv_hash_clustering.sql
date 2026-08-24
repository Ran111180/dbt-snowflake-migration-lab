{# adv_hash_clustering: HASH, SHA2, MD5 for deduplication and clustering #}
{{ config(materialized='table', tags=['advanced', 'dedup']) }}

WITH hashed AS (
  SELECT
    patient_id,
    full_name AS patient_name,
    -- Multiple hash functions for different purposes
    MD5(CONCAT(patient_id, '|', patient_name)) AS dedup_hash,
    SHA2(CONCAT(patient_id, '|', CAST(admit_date AS STRING)), 256) AS record_hash,
    HASH(patient_id) AS partition_hash,
    -- Consistent hashing for distribution
    MOD(ABS(HASH(patient_id)), 10) AS partition_bucket,
    MOD(ABS(HASH(facility_id)), 4) AS facility_shard,
    -- Dedup detection
    ROW_NUMBER() OVER (
      PARTITION BY MD5(CONCAT(patient_id, '|', patient_name, '|', CAST(admit_date AS STRING)))
      ORDER BY _ingested_at DESC
    ) AS dedup_rank,
    age,
    facility_id,
    admit_date,
    _ingested_at
  FROM {{ ref('stg_patients') }}
)
SELECT
  patient_id,
  patient_name,
  dedup_hash,
  record_hash,
  partition_bucket,
  facility_shard,
  age,
  facility_id,
  admit_date,
  IFF(dedup_rank > 1, TRUE, FALSE) AS is_duplicate,
  _ingested_at
FROM hashed
WHERE dedup_rank = 1
