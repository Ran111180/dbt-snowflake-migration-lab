{# PII masking macro - SHA256 hash #}
{% macro mask_pii(column) %}
  SHA2(CAST({{ column }} AS STRING), 256)
{% endmacro %}

{# Safe division - avoids divide by zero #}
{% macro safe_divide(numerator, denominator) %}
  CASE WHEN {{ denominator }} = 0 OR {{ denominator }} IS NULL THEN NULL
       ELSE CAST({{ numerator }} AS FLOAT) / CAST({{ denominator }} AS FLOAT)
  END
{% endmacro %}

{# Generate surrogate key from multiple columns #}
{% macro surrogate_key(field_list) %}
  MD5(CONCAT_WS('|', {% for field in field_list %}COALESCE(CAST({{ field }} AS STRING), '_null_'){% if not loop.last %}, {% endif %}{% endfor %}))
{% endmacro %}

{# Date spine generator #}
{% macro date_spine(start_date, end_date) %}
  SELECT DATEADD('day', SEQ4(), '{{ start_date }}'::DATE) AS date_day
  FROM TABLE(GENERATOR(ROWCOUNT => DATEDIFF('day', '{{ start_date }}'::DATE, '{{ end_date }}'::DATE) + 1))
{% endmacro %}

{# Age calculation from DOB #}
{% macro calc_age(dob_column) %}
  DATEDIFF('year', {{ dob_column }}, CURRENT_DATE()) 
  - IFF(DATEADD('year', DATEDIFF('year', {{ dob_column }}, CURRENT_DATE()), {{ dob_column }}) > CURRENT_DATE(), 1, 0)
{% endmacro %}

{# Clinical severity classifier #}
{% macro classify_severity(value, low_threshold, high_threshold, critical_low, critical_high) %}
  CASE
    WHEN {{ value }} <= {{ critical_low }} OR {{ value }} >= {{ critical_high }} THEN 'Critical'
    WHEN {{ value }} < {{ low_threshold }} OR {{ value }} > {{ high_threshold }} THEN 'Abnormal'
    ELSE 'Normal'
  END
{% endmacro %}

{# Convert variant to typed with fallback #}
{% macro safe_variant_cast(variant_path, target_type, default_value) %}
  COALESCE(TRY_CAST({{ variant_path }} AS {{ target_type }}), {{ default_value }})
{% endmacro %}

{# Fiscal quarter from date #}
{% macro fiscal_quarter(date_column, fiscal_year_start_month=7) %}
  CASE 
    WHEN MONTH({{ date_column }}) >= {{ fiscal_year_start_month }} 
    THEN 'Q' || CEIL((MONTH({{ date_column }}) - {{ fiscal_year_start_month }} + 1) / 3.0)::INT
    ELSE 'Q' || CEIL((MONTH({{ date_column }}) + 12 - {{ fiscal_year_start_month }} + 1) / 3.0)::INT
  END
{% endmacro %}
