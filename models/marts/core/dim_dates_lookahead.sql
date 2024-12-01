WITH source AS (
    SELECT
        *
    FROM
        {{ ref('stg_dates_lookahead') }}
),
seeds_nulls AS (
    SELECT
        {{ coalesce_defaults(ref('stg_dates_lookahead'), seed = True) }}

),
surr_nulls AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['date_key']) }} AS date_key,
        {{ dbt_utils.star(
            from = ref('stg_dates_lookahead'),
            except = ['date_key']
        ) }}
    FROM
        seeds_nulls
)
SELECT
    *
FROM
    surr_nulls
UNION ALL
SELECT
    *
FROM
    source
