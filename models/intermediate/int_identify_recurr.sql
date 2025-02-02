WITH source AS (
    

    SELECT
        DISTINCT {{ coalesce_defaults(ref('base_todos')) }}
    FROM
        {{ ref('base_todos') }}
),
identify_recurring AS (
    -- handle flagging habits
    SELECT
        *,
        CASE
            WHEN (
                todo_status <> '0'
                AND EXISTS (
                    SELECT
                        todo_id
                    FROM
                        source A
                    WHERE
                        A.todo_id = b.todo_repeattaskid
                        AND A.todo_repeatflag <> 'default'
                )
            )
            OR (
                todo_status = '0'
                AND todo_repeatflag <> 'default'
            ) THEN TRUE
            ELSE FALSE
        END AS todo_derived__is_repeat
    FROM
        source b
),

selected_fields as (
    select 
    todo_id,
    todo_title,
    todo_projectid,
    todo_repeatflag,
    todo_repeattaskid,
    todo_status,
    todo_derived__is_repeat,
    todo_completedtime
    from identify_recurring
    WHERE todo_derived__is_repeat is true
),

final as (
    select * from selected_fields
)

select * from final

