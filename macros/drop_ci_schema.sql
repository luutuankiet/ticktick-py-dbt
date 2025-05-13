{%- macro drop_ci_schema() -%}
    {% set sql %}
        DROP schema IF EXISTS "ci_gha" CASCADE;
    {% endset %}
    {% do log("Dropping database 'ci_jyeo'", info=True) %}
    {% do run_query(sql) %}
    {% do log("Databse dropped", info=True) %}
{%- endmacro -%}
