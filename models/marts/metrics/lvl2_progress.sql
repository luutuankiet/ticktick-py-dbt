WITH source AS (
    SELECT
        *
    FROM
        {{ ref('stg_lvl1_lvl2_progress') }}
    WHERE
        list_name LIKE '%-------%'
)
SELECT
    {{ dbt_utils.star(
        from = ref('stg_lvl1_lvl2_progress'),
        except = ['list_name']
    ) }}
FROM
    source
