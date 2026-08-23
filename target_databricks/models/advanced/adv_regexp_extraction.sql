{# adv_regexp_extraction: Heavy REGEXP usage for clinical note parsing #}
{{ config(materialized='table', tags=['advanced', 'nlp']) }}

SELECT
  patient_id,
  clinical_notes,
  REGEXP_EXTRACT(
    clinical_notes,
    '(Metformin|Lisinopril|Enoxaparin|Furosemide|Lasix|Aspirin|Zosyn|Azithromycin)',
    0
  ) AS first_med_mention, /* Extract medication mentions from notes */
  REGEXP_COUNT(
    clinical_notes, '(Metformin|Lisinopril|Enoxaparin|Furosemide|Lasix|Aspirin|Zosyn|Azithromycin)') AS med_mention_count,
  REGEXP_EXTRACT(clinical_notes, 'BP\\s*([0-9]+/[0-9]+)', 0) AS bp_from_notes, /* Extract vital values from notes */
  REGEXP_EXTRACT(clinical_notes, 'BNP.*?([0-9]+)', 0) AS bnp_value,
  REGEXP_EXTRACT(clinical_notes, 'GFR.*?([0-9]+)', 0) AS gfr_value,
  CASE
    WHEN REGEXP_LIKE(clinical_notes, '(?i)(admitted|admission)')
    THEN 'Admission Note'
    WHEN REGEXP_LIKE(clinical_notes, '(?i)(exacerbation|acute)')
    THEN 'Acute Event'
    WHEN REGEXP_LIKE(clinical_notes, '(?i)(routine|rehab)')
    THEN 'Routine/Rehab'
    WHEN REGEXP_LIKE(clinical_notes, '(?i)(progress|declining)')
    THEN 'Progress Note'
    ELSE 'General'
  END AS note_classification, /* Classify note type */
  REGEXP_EXTRACT(clinical_notes, '(s/p|PMH|HTN|DM2|CHF|CKD|O2|NC|PT/OT/SLP)', 0) AS first_abbreviation, /* Extract abbreviations */
  0 AS word_count /* FIXME: regex mangled by transpiler */, /* Word count */
  LENGTH(clinical_notes) AS char_count
FROM {{ ref('stg_patients') }}
WHERE
  clinical_notes IS NOT NULL