WITH source AS (
    SELECT
        *
    FROM
        {{ ref("int_add_bucket") }}
),
get_streak AS (
    {# gets streak for both wontdo and done #}
    SELECT
        COUNT(todo_done_habit_bucket_id) over (
            PARTITION BY todo_repeattaskid,
            todo_done_habit_bucket_id
        ) AS todo_done_streak,
        COUNT(todo_wontdo_habit_bucket_id) over (
            PARTITION BY todo_repeattaskid,
            todo_wontdo_habit_bucket_id
        ) AS todo_wontdo_streak,
        source.*
    FROM
        source
),
get_total_done_attempts AS (
    SELECT
        DISTINCT COUNT(todo_done_streak) over (
            PARTITION BY todo_repeattaskid
        ) AS todo_done_total_attempts,
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
get_current_bucket AS (
    SELECT
        todo_repeattaskid,
        MAX(todo_wontdo_habit_bucket_id) AS todo_current_wontdo_bucket,
        MAX(todo_done_habit_bucket_id) AS todo_current_done_bucket
    FROM
        get_streak
    GROUP BY
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
get_warning_wont_do_dim AS (
    {# dimension for flagging if a wontdo streak passed threshold #}
    {# latest bucket will always be biggest #}
    SELECT
        todo_repeattaskid,
        CASE
            WHEN todo_wontdo_streak = 1 THEN '⚠️'
            WHEN todo_wontdo_streak > 1 THEN '🆘' || todo_wontdo_streak
            ELSE ' '
        END AS todo_wontdo_bad_habit_flag
    FROM
        get_streak
    WHERE
        CONCAT(
            todo_repeattaskid,
            todo_wontdo_habit_bucket_id
        ) IN (
            SELECT
                CONCAT(
                    todo_repeattaskid,
                    todo_current_wontdo_bucket
                )
            FROM
                get_current_bucket
        )
),
flag_active_habits as (
select 
s.todo_id,
s.todo_done_habit_bucket_id = c.todo_current_done_bucket as todo_done_isactive,
s.todo_wontdo_habit_bucket_id = c.todo_current_wontdo_bucket as todo_wontdo_isactive
from source s left join 
get_current_bucket c on s.todo_repeattaskid = c.todo_repeattaskid
or s.todo_id = c.todo_repeattaskid


),

joined AS (
    {# this is where all the calculated columns rolls over to each habit groups#}
    SELECT
        mx_st.todo_done_max_streak,
        ta.todo_done_total_attempts,
        w.todo_wontdo_bad_habit_flag,
        f.todo_done_isactive,
        f.todo_wontdo_isactive,
        s.*
    FROM
        get_streak AS s
        LEFT JOIN get_max_done_streak AS mx_st
        ON (
            s.todo_id = mx_st.todo_repeattaskid
            AND s.todo_repeatflag <> 'default'
        )
        OR (
            s.todo_repeattaskid = mx_st.todo_repeattaskid
            AND s.todo_repeatflag = 'default'
        )
        LEFT JOIN get_total_done_attempts AS ta
        ON (
            s.todo_id = ta.todo_repeattaskid
            AND s.todo_repeatflag <> 'default'
        )
        OR (
            s.todo_repeattaskid = ta.todo_repeattaskid
            AND s.todo_repeatflag = 'default'
        )
        LEFT JOIN get_warning_wont_do_dim AS w
        ON (
            s.todo_id = w.todo_repeattaskid
            AND s.todo_repeatflag <> 'default'
        )
        OR (
            s.todo_repeattaskid = w.todo_repeattaskid
            AND s.todo_repeatflag = 'default'
        )
        INNER JOIN flag_active_habits f on s.todo_id = f.todo_id
),
debug AS (
    select

    {{star_cte('get_warning_wont_do_dim')}}
    from 
    get_warning_wont_do_dim

),
FINAL AS (
    SELECT
    distinct
        joined.*
    FROM
        joined
)
SELECT
    *
FROM
    final