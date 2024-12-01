WITH source AS (
    SELECT
        *
    FROM
        {{ ref('stg_lvl1_lvl2_progress') }}
    WHERE
        list_name NOT LIKE '%-------%'
)
SELECT
    *
FROM
    source
