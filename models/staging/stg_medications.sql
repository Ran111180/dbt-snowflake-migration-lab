{# stg_medications: LATERAL FLATTEN, DECODE, IFF, LISTAGG #}
{{ config(materialized='view', tags=['staging', 'pharmacy']) }}

SELECT
    raw_data:patient_id::STRING AS patient_id,
    f.value:name::STRING AS medication_name,
    f.value:dose::STRING AS dose,
    f.value:route::STRING AS route,
    f.value:frequency::STRING AS frequency,
    TRY_CAST(f.value:start_date::STRING AS DATE) AS start_date,
    f.value:prescriber::STRING AS prescriber_id,
    f.index + 1 AS medication_sequence,
    DECODE(f.value:route::STRING,
        'PO', 'Oral',
        'IV', 'Intravenous',
        'SubQ', 'Subcutaneous',
        'IM', 'Intramuscular',
        'PR', 'Rectal',
        'TOP', 'Topical',
        'Other'
    ) AS route_description,
    IFF(f.value:route::STRING IN ('IV', 'SubQ', 'IM'), TRUE, FALSE) AS is_injectable,
    IFF(f.value:route::STRING = 'IV', 'High Risk', 
        IFF(f.value:route::STRING IN ('SubQ', 'IM'), 'Moderate Risk', 'Standard')) AS risk_category,
    _ingested_at
FROM {{ source('landing', 'raw_patients') }}
    , LATERAL FLATTEN(input => raw_data:medications) AS f
