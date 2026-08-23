{# adv_regexp_extraction: Heavy REGEXP usage for clinical note parsing #}
{{ config(materialized='table', tags=['advanced', 'nlp']) }}

SELECT
    patient_id,
    clinical_notes,
    -- Extract medication mentions from notes
    REGEXP_SUBSTR(clinical_notes, '(Metformin|Lisinopril|Enoxaparin|Furosemide|Lasix|Aspirin|Zosyn|Azithromycin)', 1, 1, 'i') AS first_med_mention,
    REGEXP_COUNT(clinical_notes, '(Metformin|Lisinopril|Enoxaparin|Furosemide|Lasix|Aspirin|Zosyn|Azithromycin)', 1, 'i') AS med_mention_count,
    -- Extract vital values from notes
    REGEXP_SUBSTR(clinical_notes, 'BP\\s*([0-9]+/[0-9]+)', 1, 1, 'e') AS bp_from_notes,
    REGEXP_SUBSTR(clinical_notes, 'BNP.*?([0-9]+)', 1, 1, 'e') AS bnp_value,
    REGEXP_SUBSTR(clinical_notes, 'GFR.*?([0-9]+)', 1, 1, 'e') AS gfr_value,
    -- Classify note type
    CASE
        WHEN REGEXP_LIKE(clinical_notes, '(admitted|admission)', 'i') THEN 'Admission Note'
        WHEN REGEXP_LIKE(clinical_notes, '(exacerbation|acute)', 'i') THEN 'Acute Event'
        WHEN REGEXP_LIKE(clinical_notes, '(routine|rehab)', 'i') THEN 'Routine/Rehab'
        WHEN REGEXP_LIKE(clinical_notes, '(progress|declining)', 'i') THEN 'Progress Note'
        ELSE 'General'
    END AS note_classification,
    -- Extract abbreviations
    REGEXP_SUBSTR(clinical_notes, '(s/p|PMH|HTN|DM2|CHF|CKD|O2|NC|PT/OT/SLP)', 1, 1, 'c') AS first_abbreviation,
    REGEXP_COUNT(clinical_notes, '\\b[A-Z]{2,5}\\b') AS abbreviation_count,
    -- Word count
    ARRAY_SIZE(SPLIT(clinical_notes, ' ')) AS word_count,
    LENGTH(clinical_notes) AS char_count
FROM {{ ref('stg_patients') }}
WHERE clinical_notes IS NOT NULL
