{% macro generate_schema_name(custom_schema_name=none, node=none) -%}
    {%- set default_schema = target.schema -%}
    {%- if target.name == 'ci' -%}
        {{ env_var("CI_SCHEMA",'ci') }}
    {%- elif not custom_schema_name -%}
        {{ default_schema }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
