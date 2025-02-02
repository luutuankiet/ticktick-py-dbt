with source as (
    select * from {{ ref('int_identify_recurr') }}
),

done_bucket_mapping as (
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
        END AS habit_bucket_id,
        *
    FROM
        source
),
wontdo_bucket_mapping as (
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
        END AS habit_bucket_id,
        *
    FROM
        source
) ,

unioned as (
    select * from done_bucket_mapping
    WHERE todo_status in ('2', '0')
    UNION ALL 
    select * from wontdo_bucket_mapping
    WHERE todo_status = '-1'
),

debug as (
    select 
     habit_bucket_id,
    todo_status,
    todo_completedtime,
    todo_title,
    todo_repeattaskid


    from unioned
    {# where todo_title ='morning deepwork' #}
    where todo_repeattaskid ='661797cc7ffe5107283a524a'
    order by todo_completedtime
    
    {# select 
    max(todo_completedtime)
    from {{ref('base_todos')}}
    where todo_repeattaskid ='05734d7584d1cb0380b5cdb9' #}
),

final as ( 
    select * from unioned
)

select * from final

