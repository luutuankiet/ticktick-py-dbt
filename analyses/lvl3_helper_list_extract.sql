{% set seed_table_name = 'list_goal_mapping' %}

{% if target.name == "ci" %}
    {% set seed_table_name = seed_table_name + '_sample' %}
{% endif %}



WITH source AS (
    SELECT
        *
    FROM
        {{ ref('stg_lvl1_lvl2_progress') }}
),
ref_seeds AS (
    SELECT
        *
    FROM
        {{ ref(seed_table_name) }}
),
new_seeds AS (
    SELECT
        folder_name,
        list_name,
        '' AS goals
    FROM
        source
    WHERE folder_name != 'default'
    
)
SELECT
    n.folder_name,
    n.list_name,
    r.goals
FROM
    new_seeds n
    LEFT JOIN ref_seeds r
    ON r.folder_name = n.folder_name
    AND r.list_name = n.list_name
order by 1,2,3