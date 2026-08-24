{# adv_hash_clustering: HASH, SHA2, MD5 for deduplication and clustering #}
{{ config(materialized='table', tags=['advanced', 'dedup']) }}

WITH hashed AS (
  SELECT
    patient_id,
    full_name,
    MD5(CONCAT(patient_id, '|', full_name)) AS dedup_hash, /* Multiple hash functions for different purposes */
    SHA2(CONCAT(patient_id, '|', CAST(admit_date AS STRING)), 256) AS record_hash,
    HASH(patient_id) AS partition_hash,
    MOD(ABS(HASH(patient_id)), 10) AS partition_bucket, /* Consistent hashing for distribution */
    MOD(ABS(HASH(facility_id)), 4) AS facility_shard,
    ROW_NUMBER() OVER (
      PARTITION BY MD5(CONCAT(patient_id, '|', full_name, '|', CAST(admit_date AS STRING)))
      ORDER BY _ingested_at DESC NULLS FIRST
    ) AS dedup_rank, /* Dedup detection */
    age,
    facility_id,
    admit_date,
    _ingested_at
  FROM {{ ref('stg_patients') }}
)
SELECT
  patient_id,
  full_name,
  dedup_hash,
  record_hash,
  partition_bucket,
  facility_shard,
  age,
  facility_id,
  admit_date,
  IF(dedup_rank > 1, TRUE, FALSE) AS is_duplicate,
  _ingested_at
FROM hashed
WHERE
  dedup_rank = 1