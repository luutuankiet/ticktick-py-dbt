import ruamel.yaml
import os

os.chdir(os.path.dirname(__file__))

def load_yaml(file_path):
    yaml = ruamel.yaml.YAML()
    yaml.preserve_quotes = True
    with open(file_path, 'r') as f:
        return yaml.load(f)
    
# load file
v2_yaml = load_yaml('./fact_todos_v2.yml')
original_yaml = load_yaml('./fact_todos.yml')

# extract original yaml columns
shared_column_names = {
    og_column['name'] 
    for v2_column in v2_yaml['models'][0]['columns']
    for og_column in original_yaml['models'][0]['columns'] 
    if og_column['name'] == v2_column['name']
}

unique_v2_column_names = {
    v2_column['name']
    for v2_column in v2_yaml['models'][0]['columns']
    if v2_column['name'] not in shared_column_names
}

unique_og_column_names = {
    column['name']
    for column in original_yaml['models'][0]['columns']
    if column['name'] not in shared_column_names
}

unique_og_columns = [
    column for column in original_yaml['models'][0]['columns']
    if column['name'] in unique_og_column_names

]

# stg_og = [
#     column for column in original_yaml['models'][0]['columns']
#     if column['name'] in merged_column_names
# ]

# stg_v2 = [
#     column for column in v2_yaml['models'][0]['columns']
#     if column['name'] in merged_column_names
# ] 


out_yaml = original_yaml
out_yaml['models'][0]['columns'] = unique_og_columns

with open('merged.yml', 'w') as f:
    yaml = ruamel.yaml.YAML()
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=4, offset=2)
    yaml.dump(out_yaml,f)

print(v2_yaml)