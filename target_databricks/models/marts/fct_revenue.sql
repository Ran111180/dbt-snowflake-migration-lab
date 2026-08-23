{# fct_revenue: Incremental fact table with multiple joins #}
{{ config(
    materialized='incremental',
    unique_key='revenue_key',
    incremental_strategy='merge',
    tags=['marts', 'gold', 'billing']
) }}




SELECT
    
  MD5(CONCAT_WS('|', COALESCE(CAST(c.claim_id AS STRING), '_null_'), COALESCE(CAST(c.patient_id AS STRING), '_null_')))
 AS revenue_key,
    c.claim_id,
    c.patient_id,
    c.encounter_id,
    c.payer_name,
    c.claim_type,
    c.claim_status,
    c.service_date,
    c.total_charges,
    c.total_paid,
    c.total_denied,
    c.outstanding_amount,
    c.payment_ratio,
    c.days_to_submit,
    c.days_to_payment,
    c.is_denied,
    c.line_item_count,
    -- Join with patient info
    p.facility_id,
    p.age AS patient_age,
    p.gender AS patient_gender,
    -- Fiscal period
    
  CASE 
    WHEN MONTH(c.service_date) >= 7 
    THEN 'Q' || CEIL((MONTH(c.service_date) - 7 + 1) / 3.0)::INT
    ELSE 'Q' || CEIL((MONTH(c.service_date) + 12 - 7 + 1) / 3.0)::INT
  END
 AS fiscal_quarter,
    DATE_TRUNC('month', c.service_date) AS service_month,
    CURRENT_TIMESTAMP() AS _last_updated
FROM {{ ref('stg_claims') }} c
LEFT JOIN {{ ref('stg_patients') }} p ON c.patient_id = p.patient_id

  {% if is_incremental() %}
WHERE c._ingested_at > (SELECT MAX(_last_updated) FROM {{ this }})

  {% endif %}