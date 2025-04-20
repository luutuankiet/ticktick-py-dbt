WITH source AS (
    SELECT
        *
    FROM
        {{ ref('int_add_streak') }}
),

-- to rollup : list_title, todo_title 

roll AS (
    -- 
    SELECT
        COALESCE(
            roll.todo_title,
            base.todo_title
        ) AS todo_title,
        COALESCE(
            roll.todo_projectid,
            base.todo_projectid
        ) AS todo_projectid,
        {{ dbt_utils.star(
            ref('int_add_streak'), 
            relation_alias = 'base', 
            except = ["todo_title", "todo_projectid", "rn" ]
            ) 
        }}
    FROM
        source base
        LEFT JOIN source roll
        ON base.todo_repeattaskid = roll.todo_id
),

FINAL as (
    select * from roll
)


select * from FINAL