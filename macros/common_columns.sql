{% macro common_columns(exclude=[]) %}
    {% set all_columns = [
        'todo_id',
        'todo_repeattaskid',
        'todo_title',
        'todo_status',
        'todo_repeatflag',
        'todo_duedate',
        'todo_completedtime',
        'todo_modifiedtime',
        'todo_createdtime'
    ] %}

    {% set filtered_columns = [] %}
    {% for column in all_columns %}
        {% if column not in exclude %}
            {% do filtered_columns.append(column) %}
        {% endif %}
    {% endfor %}

    {# Initialize an empty string to hold the result #}
    {% set result = '' %}

    {# Iterate over the filtered columns and append them to the result #}
    {% for column in filtered_columns %}
        {{ column }}
        {% if not loop.last %} , {% endif %}
    {% endfor %}
{% endmacro %}
