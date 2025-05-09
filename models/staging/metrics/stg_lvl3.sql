{% set seed_table_name = 'list_goal_mapping' %}

{% if target.name == "ci" %}
    {% set seed_table_name = seed_table_name + '_sample' %}
{% endif %}


WITH MAP AS (
    SELECT
        *,
        unnest(
            regexp_split_to_array(
                goals,
                ',(?=(?:[^"]*"[^"]*")*[^"]*$)'
            )
        ) AS goal
    FROM
    {{ ref(seed_table_name) }}
),
goals AS (
    SELECT
        *
    FROM
        {{ ref('base_lvl3') }}
),
unmapped AS (
    SELECT
        *
    FROM
        {{ ref(seed_table_name) }}
    WHERE
        goals IS NULL
),
joined AS (
    SELECT
        goals.*,
        MAP.folder_name,
        MAP.list_name
    FROM
        goals
        LEFT JOIN MAP {# ON goals.goal like '%' || MAP.goal || '%' #}
        ON TRIM(goals.goal) LIKE '%' || REPLACE(TRIM(MAP.goal), '"', '') || '%'
    UNION ALL
    SELECT
        NULL AS goal_name,
        NULL AS goal_id,
        folder_name,
        list_name
    FROM
        unmapped
)
SELECT
    *
FROM
    joined
ORDER BY
    folder_name,
    list_name
