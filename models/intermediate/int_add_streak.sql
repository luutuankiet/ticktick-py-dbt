{% set exclude = [ 'todo_duedate', 'todo_completedtime', 'todo_modifiedtime', 'todo_createdtime' ] %}
WITH source AS (
    SELECT
        *
    FROM
        {{ ref('int_add_bucket') }}
),
get_streak AS (
    SELECT
        COUNT(todo_done_habit_bucket_id) over(
            PARTITION BY todo_repeattaskid,
            todo_done_habit_bucket_id
        ) AS todo_done_streak,*
    FROM
        source
),
get_total_attempts AS (
    SELECT
        DISTINCT COUNT(todo_done_streak) over (
            PARTITION BY todo_repeattaskid
        ) AS todo_total_done_attempts,
        todo_repeattaskid
    FROM
        get_streak
    WHERE
        todo_repeattaskid <> 'default'
    GROUP BY
        todo_repeattaskid,
        todo_done_streak
    ORDER BY
        todo_repeattaskid
),
get_max_done_streak AS (
    SELECT
        todo_repeattaskid,
        MAX(todo_done_streak) AS todo_done_max_streak
    FROM
        get_streak
    WHERE
        todo_repeattaskid <> 'default'
    GROUP BY
        todo_repeattaskid
),
joined AS (
    SELECT
        {# mx_st.todo_repeattaskid,
        ta.todo_repeattaskid,
        s.todo_status,
        #}
        mx_st.todo_done_max_streak,
        ta.todo_total_done_attempts,
        s.*
    FROM
        get_streak AS s
        LEFT JOIN get_max_done_streak AS mx_st
        ON s.todo_id = mx_st.todo_repeattaskid 
        OR s.todo_repeattaskid = mx_st.todo_repeattaskid
        LEFT JOIN get_total_attempts AS ta
        ON s.todo_id = ta.todo_repeattaskid 
        OR s.todo_repeattaskid = ta.todo_repeattaskid
),
debug AS (
    SELECT
        * {# {{ common_columns(exclude=exclude)}} #}
    FROM
        joined {# get_streak #}
    WHERE
        {# todo_title LIKE '%workout%' #}
        todo_title LIKE '%shutdown routine%' {# todo_id = '66310add61f0912edb3b827a' #}
    ORDER BY
        todo_duedate
),
FINAL AS (
    SELECT
        *
    FROM
        joined
)
SELECT
    *
FROM
    FINAL
