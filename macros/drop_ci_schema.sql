{%- macro drop_ci_schema() -%}
    {% set SCHEMA_DROP = env_var('CI_SCHEMA','ci') %}
    {% set sql %}
        DROP schema IF EXISTS "{{ SCHEMA_DROP }}" CASCADE;
    {% endset %}
    {% do log("Dropping schema " ~ "'" ~ SCHEMA_DROP ~ "'", info=True) %}
    {% do run_query(sql) %}
    {% do log("CI schema dropped", info=True) %}
{%- endmacro -%}
