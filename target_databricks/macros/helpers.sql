{# Databricks helper macros #}
{% macro mask_pii(column) %}SHA2(CAST({{ column }} AS STRING), 256){% endmacro %}
{% macro safe_divide(numerator, denominator) %}CASE WHEN {{ denominator }} = 0 OR {{ denominator }} IS NULL THEN NULL ELSE CAST({{ numerator }} AS DOUBLE) / CAST({{ denominator }} AS DOUBLE) END{% endmacro %}
{% macro surrogate_key(field_list) %}MD5(CONCAT_WS('|', {% for field in field_list %}COALESCE(CAST({{ field }} AS STRING), '_null_'){% if not loop.last %}, {% endif %}{% endfor %})){% endmacro %}
{% macro fiscal_quarter(date_column, fiscal_year_start_month=7) %}CASE WHEN MONTH({{ date_column }}) >= {{ fiscal_year_start_month }} THEN CONCAT('Q', CAST(CEIL((MONTH({{ date_column }}) - {{ fiscal_year_start_month }} + 1) / 3.0) AS INT)) ELSE CONCAT('Q', CAST(CEIL((MONTH({{ date_column }}) + 12 - {{ fiscal_year_start_month }} + 1) / 3.0) AS INT)) END{% endmacro %}
{% macro calc_age(dob_column) %}FLOOR(DATEDIFF(CURRENT_DATE(), {{ dob_column }}) / 365){% endmacro %}
