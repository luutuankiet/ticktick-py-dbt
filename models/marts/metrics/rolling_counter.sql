WITH source AS (
    SELECT
        *
    FROM
        {{ ref('fact_todos') }}
    WHERE
        todo_id IS NOT NULL
),
selected_fields AS (
    SELECT
        todo_id,
        todo_title,
        status_key,
        CASE
            WHEN {{ dbt_date.date_part(
                "year",
                "todo_completedtime"
            ) }} != 1900 THEN todo_completedtime :: DATE
            WHEN {{ dbt_date.date_part(
                "year",
                "todo_duedate"
            ) }} != 1900 THEN todo_duedate :: DATE
            ELSE NULL
        END AS rolling_date
    FROM
        source
),
add_keys AS (
    SELECT
        *,
        {{ dbt_utils.generate_surrogate_key(['rolling_date']) }} AS rolling_date_key
    FROM
        selected_fields
),
FINAL AS (
    SELECT
        *
    FROM
        add_keys
)
SELECT
    *
FROM
    FINAL
