import json
import os
import time
from typing import List, Dict

import boto3
import requests
from concurrent.futures import ThreadPoolExecutor

AQICN_URL = (
    "https://api.waqi.info/feed"
)

AQICN_TOKEN = os.environ["AQICN_TOKEN"]

SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]

MAX_WORKERS = 5

MAX_RETRIES = 3
RETRY_SLEEP_SECONDS = 2

BEIJING_STATION_UIDS = [
    13328,
    1451,
    450,
    13337,
    13336,
    459,
    448,
    447,
    457,
    452,
    13334,
    446,
    449,
    13340,
    473,
    460,
    458,
    464,
    462,
    13338,
    456,
    13335,
    463,
    451,
    13327,
]

# AWS

sqs = boto3.client("sqs")

# Empty result
def empty_station_data(
    uid: int,
) -> Dict:

    return {
        "source": "AQICN",

        "source_url": (
            f"{AQICN_URL}/@{uid}/"
        ),

        "station_id": uid,

        "station_name": "",

        "latitude": None,

        "longitude": None,

        "aqi": None,

        "dominant_pollutant": "",

        "measurement_time": "",

        "pm25": None,

        "pm10": None,

        "no2": None,

        "o3": None,

        "so2": None,

        "co": None,

        "temperature": None,

        "humidity": None,

        "pressure": None,

        "dew_point": None,

        "wind_speed": None,

        "wind_gust": None,
    }

# AQICN API
def query_aqicn_station(
    uid: int,
) -> Dict:

    url = f"{AQICN_URL}/@{uid}/"

    params = {
        "token": AQICN_TOKEN,
    }

    for attempt in range(
        1,
        MAX_RETRIES + 1,
    ):

        try:

            response = requests.get(
                url,
                params=params,
                timeout=30,
            )

            response.raise_for_status()

            result = response.json()

            # Check API status
            if result.get("status") != "ok":

                print(
                    f"AQICN returned non-ok "
                    f"status for station {uid}: "
                    f"{json.dumps(result, ensure_ascii=False)}"
                )

                return empty_station_data(uid)

            return result

        except requests.RequestException as e:

            print(
                f"AQICN request failed for station "
                f"{uid} "
                f"(attempt "
                f"{attempt}/{MAX_RETRIES}): "
                f"{e}"
            )

            if attempt < MAX_RETRIES:

                time.sleep(
                    RETRY_SLEEP_SECONDS
                )

    return empty_station_data(uid)

# Safe IAQI getter
def get_iaqi_value(
    iaqi: Dict,
    name: str,
):

    return iaqi.get(
        name,
        {},
    ).get(
        "v"
    )

# Flatten current station data
def flatten_station(
    result: Dict,
    uid: int,
) -> Dict:

    # If API request failed
    if "data" not in result:

        return empty_station_data(uid)

    data = result.get(
        "data",
        {},
    )

    city = data.get(
        "city",
        {},
    )

    geo = city.get(
        "geo",
        [],
    )

    latitude = (
        geo[0]
        if len(geo) > 0
        else None
    )

    longitude = (
        geo[1]
        if len(geo) > 1
        else None
    )

    iaqi = data.get(
        "iaqi",
        {},
    )

    time_data = data.get(
        "time",
        {},
    )

    return {

        "source": "AQICN",

        "source_url": (
            f"{AQICN_URL}/@{uid}/"
        ),

        "station_id": data.get(
            "idx",
            uid,
        ),

        "station_name": city.get(
            "name",
            "",
        ),

        "latitude": latitude,

        "longitude": longitude,

        "measurement_time": time_data.get(
            "iso",
            "",
        ),

        "aqi": data.get(
            "aqi",
        ),

        "dominant_pollutant": data.get(
            "dominentpol",
            "",
        ),

        "pm25": get_iaqi_value(
            iaqi,
            "pm25",
        ),

        "pm10": get_iaqi_value(
            iaqi,
            "pm10",
        ),

        "no2": get_iaqi_value(
            iaqi,
            "no2",
        ),

        "o3": get_iaqi_value(
            iaqi,
            "o3",
        ),

        "so2": get_iaqi_value(
            iaqi,
            "so2",
        ),

        "co": get_iaqi_value(
            iaqi,
            "co",
        ),

        "temperature": get_iaqi_value(
            iaqi,
            "t",
        ),

        "humidity": get_iaqi_value(
            iaqi,
            "h",
        ),

        "pressure": get_iaqi_value(
            iaqi,
            "p",
        ),

        "dew_point": get_iaqi_value(
            iaqi,
            "dew",
        ),

        "wind_speed": get_iaqi_value(
            iaqi,
            "w",
        ),

        "wind_gust": get_iaqi_value(
            iaqi,
            "wg",
        ),
    }

# Get one station
def get_station_data(
    uid: int,
) -> Dict:

    try:

        result = query_aqicn_station(
            uid
        )

        # API failed
        if "data" not in result:

            return result

        return flatten_station(
            result,
            uid,
        )

    except Exception as e:

        print(
            f"Failed to process station "
            f"{uid}: "
            f"{type(e).__name__}: {e}"
        )

        return empty_station_data(
            uid
        )

# Build SQS message
def build_message(
    records: List[Dict],
) -> Dict:

    return {

        "source": "AQICN",

        "record_count": len(
            records
        ),

        "records": records,
    }

# Send to SQS
def send_to_sqs(
    message: Dict,
):

    response = sqs.send_message(

        QueueUrl=SQS_QUEUE_URL,

        MessageBody=json.dumps(
            message,
            ensure_ascii=False,
        ),
    )

    print(
        f"SQS message sent: "
        f"{response['MessageId']}"
    )

# Lambda Handler
def lambda_handler(
    event,
    context,
):

    print(
        "Starting AQICN collection..."
    )
    with ThreadPoolExecutor(
        max_workers=MAX_WORKERS,
    ) as executor:

        all_records = list(
            executor.map(
                get_station_data,
                BEIJING_STATION_UIDS,
            )
        )

    print(
        f"Collected "
        f"{len(all_records)} station records"
    )

    # 2. Build SQS message
    message = build_message(
        all_records
    )

    # 3. Send to SQS
    send_to_sqs(
        message
    )

    # 4. Lambda response
    return {

        "statusCode": 200,

        "source": "AQICN",

        "record_count": len(
            all_records
        ),
    }