select distinct
    goal_id,
    lvl3_goal,
    lvl3_done_progress
from {{ ref('stg_lvl3_progress') }}
order by 1
