with source as (
    select * from {{ ref('int_add_bucket') }}
),

final as ( 
    select * from source
)

select * from final