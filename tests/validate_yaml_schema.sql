{% set models = [] %}
{# validate_type accepts 'path' or 'tag' #}
{% set validate_type = var('type', 'path') %}
{% set validate_value = var('value', '') %}
{{ "-- DEBUG: test ran with: type = '" ~ validate_type  ~ "', value = '" ~ validate_value ~ "'" }}


{% for node in graph.nodes.values() | selectattr("resource_type", "equalto", "model") %}
    {% if node.columns | count > 0 %}
        {% if validate_type == 'path' and node.path.startswith(validate_value) %}
            {% do models.append(node) %}
        {% elif validate_type == 'tag' and validate_value in node.tags %}
            {% do models.append(node) %}
        {% endif %}
    {% endif %}
{% endfor %}


{% for model in models %}
    SELECT
    NULL AS placeholder
    FROM {{ model.database ~ "." ~ model.schema ~ "." ~ model.name }}
    WHERE 1=0
    {% for column_name in model.columns %}
        AND {{ column_name }} IS NULL
    {% endfor %}
    {% if not loop.last %}UNION ALL{% endif %}
{% endfor %}
