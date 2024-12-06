{# had to hardcode the pre hook cause otherwise the old dummy lookahead dates gonn persist & build up #}
{{ config(
    materialized='incremental',
    unique_key = ['todo_lookahead_skey'],
    incremental_strategy = 'merge',
    on_schema_change='append_new_columns',
    pre_hook = ['{{cleanup_nulls("todo_id")}}'],
    post_hook = ["{% if not is_incremental() %} {{ setup_textsearch() }} {% endif %}"]

    
) }}
WITH source AS (
    SELECT
    DISTINCT

        *
    FROM
        {{ ref('stg_todos_join_lookahead') }}
)
SELECT
    *
FROM
    source

{% if is_incremental() %}
  WHERE 
  _modified_time >= (select coalesce(max(_modified_time),'1900-01-01 00:00:00') from {{ this }} )
  OR
  todo_modifiedtime IS NULL
{% endif %}
