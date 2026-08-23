{% snapshot snp_patient_insurance %}

{{ config(
    target_database='DBT_MIGRATION_LAB',
    target_schema='SNAPSHOTS',
    unique_key='patient_id',
    strategy='check',
    check_cols=['payer_name', 'plan_id', 'coverage_type'],
) }}

SELECT
    patient_id,
    payer_name,
    plan_id,
    group_id,
    coverage_type,
    effective_date,
    is_primary,
    months_enrolled,
    _ingested_at AS updated_at
FROM {{ ref('stg_insurance') }}
WHERE is_primary = TRUE

{% endsnapshot %}
