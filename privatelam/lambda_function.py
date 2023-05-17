import json
import requests
import logging
import boto3

client = boto3.client('ssm')

def get_weather_desc_and_temp():
    parm = client.get_parameter(Name='weather-api-key', WithDecryption=True)
    api_key = parm['Parameter']['Value']
    city = "Baltimore"
    url = "http://api.openweathermap.org/data/2.5/weather?q="+city+"&appid="+api_key+"&units=imperial"

    request = requests.get(url)
    request.raise_for_status()
    json = request.json()

    # reference weather.json for an example of the data for this.
    description = json.get("weather")[0].get("description")
    temp_min = json.get("main").get("temp_min")
    temp_max = json.get("main").get("temp_max")

    return {'description': description,
            'temp_min': temp_min,
            'max_temp': temp_max}

def lambda_handler(event, context):
    weather_dict = get_weather_desc_and_temp()
    print("Todays forecast is", weather_dict.get('description'))
    print("Todays low is", weather_dict.get('temp_min'))
    print("Todays high is", weather_dict.get('temp_max'))