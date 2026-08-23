{# adv_json_reconstruction: OBJECT_CONSTRUCT, ARRAY_CONSTRUCT, complex JSON building #}
{{ config(materialized='table', tags=['advanced', 'json']) }}

WITH patient_data AS (
  SELECT
    p.patient_id,
    p.full_name,
    p.age,
    p.gender,
    p.facility_id,
    p.diagnosis_count,
    p.medication_count
  FROM {{ ref('stg_patients') }} AS p
), patient_diagnoses AS (
  SELECT
    patient_id,
    TRANSFORM(
      ARRAY_SORT(
        ARRAY_AGG(
          NAMED_STRUCT(
            'value',
            STRUCT(
              icd10_code AS code,
              diagnosis_description AS description,
              is_primary AS is_primary,
              severity AS severity
            ),
            'sort_by_0',
            diagnosis_sequence
          )
        ),
        (left, right) -> CASE
                                WHEN left.sort_by_0 < right.sort_by_0 THEN -1 WHEN left.sort_by_0 > right.sort_by_0 THEN 1
                                ELSE 0
                            END
      ),
      s -> s.value
    ) AS diagnoses_array
  FROM {{ ref('stg_diagnoses') }}
  GROUP BY
    patient_id
), patient_meds AS (
  SELECT
    patient_id,
    TRANSFORM(
      ARRAY_SORT(
        ARRAY_AGG(
          NAMED_STRUCT(
            'value',
            STRUCT(
              medication_name AS name,
              dose AS dose,
              route AS route,
              frequency AS frequency,
              is_injectable AS is_injectable
            ),
            'sort_by_0',
            medication_sequence
          )
        ),
        (left, right) -> CASE
                                WHEN left.sort_by_0 < right.sort_by_0 THEN -1 WHEN left.sort_by_0 > right.sort_by_0 THEN 1
                                ELSE 0
                            END
      ),
      s -> s.value
    ) AS medications_array
  FROM {{ ref('stg_medications') }}
  GROUP BY
    patient_id
)
SELECT
  pd.patient_id,
  STRUCT(
    pd.patient_id AS patient_id,
    STRUCT(pd.full_name AS name, pd.age AS age, pd.gender AS gender, pd.facility_id AS facility) AS demographics,
    STRUCT(
      pd.diagnosis_count AS diagnosis_count,
      pd.medication_count AS medication_count,
      COALESCE(dx.diagnoses_array, ARRAY()) AS diagnoses,
      COALESCE(meds.medications_array, ARRAY()) AS medications
    ) AS clinical,
    STRUCT(CAST(CURRENT_TIMESTAMP() AS STRING) AS generated_at, '2.0' AS version) AS metadata
  ) AS patient_fhir_bundle,
  SIZE(COALESCE(dx.diagnoses_array, ARRAY())) AS actual_dx_count,
  SIZE(COALESCE(meds.medications_array, ARRAY())) AS actual_med_count
FROM patient_data AS pd
LEFT JOIN patient_diagnoses AS dx
  ON pd.patient_id = dx.patient_id
LEFT JOIN patient_meds AS meds
  ON pd.patient_id = meds.patient_id