select 
{# {{ exceptions.raise_compiler_error(context['context']['model'])}} #}

{{star_cte('get_streak','int_add_streak')}}

from

{{ref('int_add_streak')}}