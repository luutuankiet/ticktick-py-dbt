{# had to hardcode the pre hook cause otherwise the old dummy lookahead dates gonn persist & build up #}
{{ config(
    materialized='table',
    unique_key = ['todo_lookahead_skey'],
    incremental_strategy = 'merge',
    on_schema_change='append_new_columns',
    pre_hook = ['{{cleanup_nulls("todo_id")}}'],
    post_hook = ["{% if not is_incremental() %} {{ setup_textsearch() }} {% endif %}"]
) }}
{# extract the base columns from models/intermediate/int_identify_recurr.sql #}
{% set streaks_base_column = dbt_utils.get_filtered_columns_in_relation(
    from = ref('int_identify_recurr'),
    except = ['todo_derived__is_repeat']
) %}
WITH source AS (

    SELECT
        DISTINCT *
    FROM
        {{ ref('stg_todos_join_lookahead') }}
),
streak_analytics AS (
    SELECT
        *
    FROM
        {{ ref('int_streak_rollup') }}
),
joined AS (
    SELECT
        -- grab new fields from the model
        {{ dbt_utils.star(ref('int_streak_rollup'), except = streaks_base_column, relation_alias = 'sa') }},
        -- the base fact todos fields
        {{ dbt_utils.star(ref('stg_todos_join_lookahead'), relation_alias = 's') }}
    FROM
        source s
        LEFT JOIN streak_analytics sa
        ON s.todo_id = sa.todo_id)
    SELECT
        *
    FROM
        joined

{% if is_incremental() %}
  WHERE 
  _modified_time >= (select coalesce(max(_modified_time),'1900-01-01 00:00:00') from {{ this }} )
  OR
  todo_modifiedtime IS NULL
{% endif %}
