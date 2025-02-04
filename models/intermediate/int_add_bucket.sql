with source as (
    select * FROM {{ ref('int_identify_recurr') }}
),

add_done_bucket_id as (
    -- create buckets
    SELECT
        CASE
            WHEN todo_status = '2' THEN SUM(
                CASE
                    WHEN todo_status = '2' THEN 1
                    ELSE 0
                END
            ) over (
                PARTITION BY todo_repeattaskid
                ORDER BY
                    todo_completedtime rows BETWEEN unbounded preceding
                    AND CURRENT ROW
            ) 
            
            - ROW_NUMBER() over (
                PARTITION BY todo_repeattaskid
                ORDER BY
                    todo_completedtime
            ) + 1
            ELSE NULL
        END AS done_habit_bucket_id,
        *
    FROM
        source
),
add_wontdo_bucket_id as (
        -- create buckets
    SELECT
        CASE
            WHEN todo_status = '-1' THEN SUM(
                CASE
                    WHEN todo_status = '-1' THEN 1
                    ELSE 0
                END
            ) over (
                PARTITION BY todo_repeattaskid
                ORDER BY
                    todo_completedtime rows BETWEEN unbounded preceding
                    AND CURRENT ROW
            ) 
            
            - ROW_NUMBER() over (
                PARTITION BY todo_repeattaskid
                ORDER BY
                    todo_completedtime
            ) + 1
            ELSE NULL
        END AS wontdo_habit_bucket_id,
        *
    FROM
        source
) ,

unioned as (
    select 
    done_habit_bucket_id,
    NULL as wontdo_habit_bucket_id,
    {{ dbt_utils.star(ref('int_identify_recurr'))}}
    FROM add_done_bucket_id
    WHERE todo_status in ('2', '0') -- so that both new and latest done todo  in same bucket

    UNION ALL 
    select 
    NULL as done_habit_bucket_id,
    wontdo_habit_bucket_id,
    {{ dbt_utils.star(ref('int_identify_recurr'))}}
    FROM add_wontdo_bucket_id
    WHERE todo_status = '-1'
),

debug as (
    select 
    done_habit_bucket_id,
    wontdo_habit_bucket_id,
    todo_status,
    todo_completedtime,
    todo_title,
    todo_repeattaskid


    FROM unioned
    {# where todo_title ='morning deepwork' #}
    where todo_repeattaskid ='661797cc7ffe5107283a524a'
    {# where todo_repeattaskid ='6583f9868f08a6578069f73b' #}
    order by todo_completedtime::timestamp desc
    
),

final as ( 
    select * FROM unioned
)

select * FROM final