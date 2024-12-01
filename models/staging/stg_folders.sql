WITH source AS (
    SELECT
         {{coalesce_defaults(ref(
            'base_folders'
        ) )}}
    FROM
        {{ ref(
            'base_folders'
        ) }}
)
 
SELECT
    {{ dbt_utils.generate_surrogate_key(['folder_id']) }} AS folder_key,*
FROM
    source
