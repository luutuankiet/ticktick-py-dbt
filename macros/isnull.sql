{% macro isnull(field) %}
case when {{field}} is null then true else false end
  
{% endmacro %}