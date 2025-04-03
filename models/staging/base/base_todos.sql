{{ config(
    materialized = 'table'
) }}

{% set datetime_list = ['todo_createdtime', 'todo_completedtime', 'todo_startdate', 'todo_duedate', 'todo_modifiedtime'] %}
WITH raw_source_active AS (
    {# direct pull from tick api. contains current data. #}

    SELECT
        {{ dbt_utils.star(
            from = source(
                'raw_data',
                'tasks_raw'
            ),
            except = ['modifiedtime']
        ) }},
        -- gotta explicitly handle this cauaes snap's data casted as timestamp
        modifiedtime :: text AS modifiedtime,
        ROW_NUMBER() over (
            PARTITION BY id
            ORDER BY
                modifiedtime DESC
        ) AS rn
    FROM
        {{ source(
            'raw_data',
            'tasks_raw'
        ) }}
),
source_active AS (
    {# to handle de dupes #}
    SELECT
        *
    FROM
        raw_source_active
    WHERE
        rn = 1
),
source_snp AS (
    {# pulls the deleted portion of the data that is gone from tick api. #}
    SELECT
        {{ dbt_utils.star(
            from = source(
                'raw_data',
                'tasks_raw'
            ),
            except = ['modifiedtime','deleted']
        ) }},
        -- gotta explicitly handle this cauaes snap's data casted as timestamp
        modifiedtime :: text AS modifiedtime,
        true :: text as deleted
    FROM
        {{ ref(
            'snp_tasks_raw',
        ) }}
    WHERE
        dbt_valid_to IS NOT NULL
        AND id NOT IN (
            SELECT
                DISTINCT id
            FROM
                source_active
        ) -- filters out those deleted with same id but diff etag, in which we favors the active data.
),
source AS (
    SELECT
        {{ setup_nulls(source('raw_data', 'tasks_raw')) }}
    FROM
        source_active
    UNION ALL
    SELECT
        {{ setup_nulls(source('raw_data', 'tasks_raw')) }}
    FROM
        source_snp
),

process_false_completed as (
    {# sometimes new tasks with status = 0 have completed time. to wrangle this. #}
    SELECT 
    {{dbt_utils.star(
        from = source('raw_data','tasks_raw'),
        except = ['completedtime','status']
    )}},
    case when status = '0' and completedtime is not null then null 
    else completedtime 
    end as completedtime,
    
    case when status = '1' and completedtime is null then '0'
    when status = '1' and completedtime is not null then '2'
    else status
    end as status


    from source
),


renamed AS (
    SELECT
        DISTINCT {{ adapter.quote("id") }} :: text AS "todo_id",
        {# {{ adapter.quote("completedtime") }} :: TIMESTAMP AS "todo_completedtime", #}
        {# these dates MUST be converted to ETC #}
        {{ adapter.quote("completedtime") }} :: TIMESTAMP + INTERVAL '7 hours' AS "todo_completedtime",
        {{ adapter.quote("startdate") }} :: TIMESTAMP + INTERVAL '7 hours' AS "todo_startdate",
        {{ adapter.quote("duedate") }} :: TIMESTAMP + INTERVAL '7 hours' AS "todo_duedate",
        {{ adapter.quote("modifiedtime") }} :: TIMESTAMP + INTERVAL '7 hours' AS "todo_modifiedtime",
        {{ adapter.quote("createdtime") }} :: TIMESTAMP + INTERVAL '7 hours' AS "todo_createdtime",
        {{ adapter.quote("repeatfirstdate") }} :: TIMESTAMP + INTERVAL '7 hours' AS "todo_repeatfirstdate",
        {#                                           #}
        {{ adapter.quote("projectid") }} :: text AS "todo_projectid",
        {{ adapter.quote("sortorder") }} :: bigint AS "todo_sortorder",
        {{ adapter.quote("title") }} :: text AS "todo_title",
        {{ adapter.quote("content") }} :: text AS "todo_content",
        {{ adapter.quote("desc") }} :: text AS "todo_desc",
        {{ adapter.quote("timezone") }} :: text AS "todo_timezone",
        {{ adapter.quote("isfloating") }} :: BOOLEAN AS "todo_isfloating",
        {{ adapter.quote("isallday") }} :: BOOLEAN AS "todo_isallday",
        {{ adapter.quote("reminder") }} :: text AS "todo_reminder",
        {{ adapter.quote("reminders") }} :: text AS "reminders",
        -- array
        {{ adapter.quote("exdate") }} :: text AS "todo_exdate",
        {{ adapter.quote("priority") }} :: INT AS "todo_priority",
        {{ adapter.quote("status") }} :: text AS "todo_status",
        {{ adapter.quote("items") }} :: text AS "todo_items",
        {{ adapter.quote("progress") }} :: FLOAT AS "todo_progress",
        {{ adapter.quote("etag") }} :: text AS "todo_etag",
        {{ adapter.quote("deleted") }} :: BOOLEAN AS "todo_deleted",
        {{ adapter.quote("creator") }} :: INT AS "todo_creator",
        {{ adapter.quote("focussummaries") }} :: text AS "todo_focussummaries",
        {{ adapter.quote("columnid") }} :: text AS "todo_columnid",
        {{ adapter.quote("kind") }} :: text AS "todo_kind",
        {{ adapter.quote("imgmode") }} :: text AS "todo_imgmode",
        {{ adapter.quote("tags") }} :: text AS "todo_tags",
        {{ adapter.quote("repeatfrom") }} :: INT AS "todo_repeatfrom",
        {{ adapter.quote("attachments") }} :: text AS "todo_attachments",
        -- json
        {{ adapter.quote("repeattaskid") }} :: text AS "todo_repeattaskid",
        {{ adapter.quote("commentcount") }} :: FLOAT AS "todo_commentcount",
        {{ adapter.quote("completeduserid") }} :: text AS "todo_completeduserid",
        -- "120295392.0"
        {{ adapter.quote("repeatflag") }} :: text AS "todo_repeatflag",
        {{ adapter.quote("pinnedtime") }} :: TIMESTAMP AS "todo_pinnedtime",
        {{ adapter.quote("childids") }} :: text AS "childids",
        -- array
        {{ adapter.quote("deletedtime") }} :: text AS "todo_deletedtime",
        -- some weird epoc time ? "120295392.0" >>> to_timestamp(1669956236000 / 1000)
        {{ adapter.quote("pomodorosummaries") }} :: text AS "todo_pomodorosummaries",
        -- array
        {{ adapter.quote("parentid") }} :: text AS "todo_parentid",
        {{ adapter.quote("annoyingalert") }} :: text AS "todo_annoyingalert",
        {{ adapter.quote("modifiedtime_humanize") }} :: text AS "todo_modifiedtime_humanize",
        {{ adapter.quote("duedate_humanize") }} :: text AS "todo_duedate_humanize",
        ROW_NUMBER() over(
            PARTITION BY {{ dbt_utils.star(
                from = source(
                    'raw_data',
                    'tasks_raw'
                )
            ) }}
            ORDER BY
                modifiedtime DESC
        ) AS rn
    FROM
        process_false_completed
    GROUP BY
        {{ dbt_utils.star(
            from = source(
                'raw_data',
                'tasks_raw'
            )
        ) }}
),
refine_dates AS (
    {# create derived fields to parse date from timestamp fields #}
    SELECT
        DISTINCT *,
        {{ parse_date(datetime_list) }}
    FROM
        renamed
    WHERE
        rn = 1
),


final as (
    select * from refine_dates
),

debug as (
    select 
    
    {# distinct todo_title #}
    {{common_columns()}}

     from refine_dates
     where todo_title like '%schedule some cloudskillsboost path%' 
     {# or todo_repeattaskid = '651faed48f08a002fdc1e77a' #}
     {# where todo_repeattaskid is not null #}
     {# and todo_repeatflag is not null  #}
     {# and todo_id <> todo_repeattaskid #}
     order by todo_modifiedtime

)




SELECT
    *
FROM
    final
