{%- macro star_cte(cte_name, model_name=none, relation_alias=none,prefix='', suffix='', quote_identifiers=True) -%} 
{%- set re = modules.re -%}
{%- set ns = namespace(model_name=model_name, found_cte=false, cte_content=[]) -%}
{%- set parsed_model = context['context']['model'] -%}
{%- if execute -%}

    {%- if not model_name and 'from remote system.sql' in parsed_model['original_file_path'] -%}
    {# TODO: this.model_name dont work with dbt power user. #}
    {# needed to do a different approach to get the model name like so. for now it works.#}
    {# https://github.com/AltimateAI/vscode-dbt-power-user/issues/938 #}

        {%- set regex_hash_match = '[\s\n]+' -%}
        {%- set regex_words_count = 100 -%}
        {%- set target_sql = parsed_model['raw_code'] -%}
        {%- set target_sql = re.sub(regex_hash_match,'',target_sql)[:regex_words_count] -%}
        {%- for node in graph.nodes.values() -%}

            {%- set node_raw_code = re.sub(regex_hash_match,'', node['raw_code']) -%}       
            {%- set node_raw_code = node_raw_code[:regex_words_count] -%}       
            {%- if node_raw_code == target_sql -%} 
                {%- set ns.model_name = node['name'] -%}

                {%- break -%}
            {%- endif -%}

        {%- endfor -%}

    {# {% do exceptions.raise_compiler_error('debug: ' ~ parsed_model )  %} #}
    {%- elif not ns.model_name -%}
        {%- set ns.model_name = this.name -%}
    {%- endif -%}

    {{- 
        exceptions.raise_compiler_error(
            'cannot auto detect model file for ' ~ 
            "'" ~ context['context']['model']['unique_id'] ~ "'" ~ 
            '. Please manually provide the model_name arg.'
            )  if (
            graph.nodes.values()
            | selectattr('name', 'equalto', ns.model_name) 
            | selectattr('resource_type', 'equalto', 'model')
            | list 
            | length == 0
            )
        -}}

    {# Get the compiled SQL of the model #}
    {%- set model_sql = codegen.generate_model_import_ctes(ns.model_name) -%}
    {# this return as a passthru for when the macro is compiled after which is the actual exec #}
        {%- if 'select' not in model_sql|lower() -%} 
        {{- exceptions.raise_compiler_error('cannot parse cte.') -}}
        {%- endif -%}
        
        {# Split SQL into lines to find the CTE pattern #}
        {%- set lines = model_sql.split('\n') -%}

        {# Variables to track CTE boundaries #}

        {%- set cte_pattern = cte_name|lower ~ " as (" -%}
        
        {# Find the CTE and collect its content #}

        {%- set closing_cte_pattern = 'from\s+\w+\s*\n*\)' -%}
        {%- for line in lines -%}
            {%- if not ns.found_cte and cte_pattern in line|lower -%}
                {%- set ns.found_cte = true -%}
                {%- do ns.cte_content.append(line) -%}
                {%- continue -%}
            {%- elif ns.found_cte -%}
                {%- do ns.cte_content.append(line) -%}
                {%- set regex_match = re.search(closing_cte_pattern, line|lower)-%}
                {%- if regex_match -%}
                    {%- break -%}
                {%- endif -%}
            {%- endif -%}
        {%- endfor -%}

        {# If CTE not found, return empty list #}
        {%- if not ns.found_cte -%}
        {%- do exceptions.raise_compiler_error('cannot parse cte.') -%}
        {%- endif -%}

        {# Join CTE content back into a string #}
        {%- set cte_sql = ns.cte_content|join('\n') -%}
    












        {# Find the SELECT statement within the CTE #}
        {%- set select_pattern = 'select' -%}
        {%- set from_pattern = 'from' -%}
        {%- set cte_sql_lower = cte_sql|lower -%}
        
        
        {# Find positions of SELECT and FROM #}
        {%- set select_pos = cte_sql_lower.find(select_pattern) -%}
        {%- if select_pos >= 0 -%}


            {%- set from_pos = cte_sql_lower.find(from_pattern, select_pos) -%}
        {%- else -%}
            {%- set from_pos = -1 -%}
        {%- endif -%}

        
        
        {# Extract columns section between SELECT and FROM #}
        {%- set columns_section = cte_sql[select_pos + 6:from_pos].strip() -%}

        

        {# Split into individual columns #}
        {%- set raw_columns = columns_section.split(',') -%}
        {%- set columns = [] -%}

        
        {# Process each column to clean it up #}
        {%- for col in raw_columns -%}
            {%- set cleaned_col = col.strip().lower() -%}
            {#  #}
            {%- set re_comments_pattern = '[-]{2}.*$' -%}
            {%- set cleaned_col = re.sub(re_comments_pattern, '', cleaned_col) -%}
            {#  #}
            {%- if cleaned_col == '' -%} {%- continue -%} {%- endif -%}

            {# Extract alias if it exists #}
            {%- if ' as ' in cleaned_col|lower -%}
                {%- set alias = cleaned_col.split(' as ')|last -%}
                {%- set cleaned_col = alias -%}
            {%- elif 'dbt_utils.star' in col -%}
                {%- set model_pattern = "ref\\('([^']*)'\\)" -%}
                {%- set model_match = modules.re.search(model_pattern, col) -%}
                {%- if model_match -%}
                    {%- set model_name = model_match.group(1) -%}
                    {%- set star_columns = dbt_utils.get_filtered_columns_in_relation(from=ref(model_name)) -%}
                    {%- for col in star_columns -%}
                        {%- do columns.append(col) -%}
                    {%- endfor-%}
                {%- endif -%}
                {%- continue -%}

            {%- elif ')' in cleaned_col and not ' by ' in cleaned_col|lower -%} {# "Argments to functions shouldn't be treated as column names" #}
                {%- set col_tidied = col.strip().split(' ') | last -%}
                {%- set cleaned_col = col_tidied -%}
                
            {%- elif '(' in cleaned_col or ' by ' in cleaned_col|lower -%}
                {%- continue -%}
            {%- endif -%}
            {%- if '.' in cleaned_col -%}
            {%- set cleaned_col = cleaned_col.split('.')|last -%}
            {%- endif -%}

            {%- do columns.append(cleaned_col) -%}
        {%- endfor -%}


{#  starts laying out the columns #}


        {%- for col in columns -%}
            {%- if '*' in col -%} * {%- continue -%} {%- endif -%}
            {%- if relation_alias -%}{{- relation_alias -}}.{%- else -%}{%- endif -%}
                {%- if quote_identifiers -%}
                    {{- adapter.quote(col)|trim -}} {%- if prefix!='' or suffix!='' -%} as {{- adapter.quote(prefix ~ col ~ suffix)|trim -}} {%- endif -%}
                {%- else -%}
                    {{- col|trim -}} {%- if prefix!='' or suffix!='' -%} as {{- (prefix ~ col ~ suffix)|trim -}} {%- endif -%}
                {%- endif -%}
            {%- if not loop.last -%},{{- '\n  ' -}}{%- endif -%}
        {%- endfor -%}




{%- endif -%}
   
{%- endmacro -%}
