with source as (
    select * from {{ ref('int_add_bucket') }}
),

calc_streak_done as (
    select 
    *

    from source
    where todo_status in ('2','0')
),

final as ( 
    select * from source
)

select * from final