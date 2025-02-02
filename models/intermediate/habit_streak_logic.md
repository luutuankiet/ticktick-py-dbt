{% docs habit_streak_logic %}

weird issue i had to do this
`pip install --prefer-binary dbt-postgres`
`pip install dbt-core`

<!-- -- current -->
# Habit Streak Calculation Logic

## Input Data
- Todo tasks with status, dates, and repeat task flags
- Status codes: 0 (active), 2 (completed), -1 (undone)

## Calculation Steps

1. **Identify Recurring Tasks**
   - Flag tasks where:
     - Parent task exists with non-default repeat flag OR
     - Active task with non-default repeat flag

2. **Create Completion Streak Buckets**
   - Partition by repeat task ID
   - Order by completion time
   - Calculate running sum of completed tasks
   - Subtract row number to group consecutive completions

3. **Calculate Streak Length**
   - Group by repeat task ID and bucket ID
   - Count rows within each bucket
   - Assign streak count to each task

4. **Track Consecutive Undone Tasks**
   - Similar window partitioning for undone status
   - Create buckets for consecutive undone tasks
   - Calculate running count of undone tasks

5. **Handle Edge Cases**
   - Reset streaks when task status changes
   - Link child tasks to parent task properties
   - Maintain latest task title and project ID

## Output Fields
- todo_derived__habit_streak: Current streak count
- todo_derived__consecutive_undone: Count of consecutive misses
- todo_derived__is_repeat: Habit task flag

This logic enables habit tracking and streak analysis for recurring tasks in the system.


# Habit Streak Tracking Approaches

## 1. Date-Based Gap Analysis
WITH date_gaps AS (
  SELECT 
    todo_id,
    todo_completedtime,
    DATEDIFF('day', 
      LAG(todo_completedtime) OVER (PARTITION BY todo_repeattaskid ORDER BY todo_completedtime),
      todo_completedtime
    ) as days_since_last_completion
  FROM todos
)
- Tracks actual completion intervals
- Handles irregular patterns
- Configurable break thresholds

## 2. Calendar Spine Method
WITH calendar AS (
  SELECT date_day 
  FROM dim_calendar
),
habit_calendar AS (
  SELECT 
    c.date_day,
    t.todo_id,
    CASE WHEN t.todo_completedtime IS NOT NULL THEN 1 ELSE 0 END as completed
  FROM calendar c 
  LEFT JOIN todos t ON DATE(t.todo_completedtime) = c.date_day
)
- Full visibility of all days
- Perfect for consistency analysis
- Supports frequency tracking

## 3. State Machine Approach
SELECT 
  todo_id,
  status,
  LAG(status) OVER (ORDER BY todo_completedtime) as prev_status,
  CASE 
    WHEN status = prev_status THEN 0 
    ELSE 1 
  END as state_change
- Clear state transitions
- Flexible streak rules
- Maintainable logic

## 4. Rolling Window Method
SELECT 
  todo_id,
  COUNT(*) OVER (
    PARTITION BY todo_repeattaskid 
    ORDER BY todo_completedtime 
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  ) as rolling_7day_completions
- Adaptable streak definitions
- Multiple time window support
- Trend analysis ready

## Selection Criteria
Choose based on:
- Streak definition requirements
- Performance needs
- Analysis depth
- Data volume
- Update frequency

{% enddocs %}