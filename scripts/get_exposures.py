import json
import requests
from dotenv import load_dotenv
import os

load_dotenv()

BASE_URL=os.getenv("BASE_URL","")
API_KEY=os.environ.get("API_KEY","")
HEADERS = {
    "Authorization": f"ApiKey {API_KEY}"
}
PROJECT_ID=os.environ.get("PROJECT_ID","")

GET_DASHBOARD_CODE_ENDPOINT= BASE_URL + "/projects/{projectUuid}/dashboards/code".format(projectUuid=PROJECT_ID)
GET_CHART_CODE_ENDPOINT= BASE_URL + "/projects/{projectUuid}/charts/code".format(projectUuid=PROJECT_ID)
GET_EXPLORE_DETAILS_ENDPOINT= BASE_URL + "/projects/{projectUuid}/explores/{{exploreId}}".format(projectUuid=PROJECT_ID)



# parse dashboards


latest_dashes = ["habit v2"]
# latest_dashes = ["GTD dash 0.4"]
dashboard_json = requests.get(GET_DASHBOARD_CODE_ENDPOINT, headers=HEADERS).json()
target_dashes: list[dict] = [
    dash for dash in 
    dashboard_json['results']['dashboards'] 
    if dash['name'] in latest_dashes
    ]

tiles: list[dict] = [
    tile
    for dash in target_dashes
    for tile in dash['tiles']
]


# parse charts

target_charts: list[str] = [
    tile['properties']['chartSlug'] for tile in tiles
    if tile['type'] == 'saved_chart'
]


chart_json = requests.get(GET_CHART_CODE_ENDPOINT, headers=HEADERS).json()
explores: set[str]= {
    chart['metricQuery']['exploreName'] 
    for chart in chart_json['results']['charts']
    if chart['slug'] in target_charts
}



# parse explores


explore_details: list[dict] = []
for explore in explores:
    url = GET_EXPLORE_DETAILS_ENDPOINT.format(exploreId=explore)
    response = requests.get(url, headers=HEADERS)
    explore_details.append(response.json()['results'])





# parse tables

tables = [
    table['name']
    for explore in explore_details
    for table in explore['tables'].values()
]

with open('table.json', 'w') as f:
    json.dump(tables, f, indent=4)

print(tables)