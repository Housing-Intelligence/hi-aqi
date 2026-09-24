import json
import math
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import List, Dict

import boto3


OPEN_METEO_URL = (
    "https://air-quality-api.open-meteo.com/v1/air-quality"
)

MIN_LAT = 39.3
MAX_LAT = 41.0

MIN_LON = 115.3
MAX_LON = 117.6

GRID_LAT_STEP = 0.1
BATCH_SIZE = 50

FORECAST_HOURS = 1
TIMEZONE = "Asia/Shanghai"
CELL_SELECTION = "nearest"

MAX_RETRIES = 3
RETRY_SLEEP_SECONDS = 2

HOURLY_VARIABLES = [
    "pm2_5",
    "pm10",
    "nitrogen_dioxide",
    "ozone",
    "sulphur_dioxide",
    "carbon_monoxide",
]

sqs = boto3.client("sqs")

SQS_QUEUE_URL = os.environ["SQS_QUEUE_URL"]


# Generate sampling grid
def generate_grid_points() -> List[Dict[str, float]]:

    points = []

    lat = MIN_LAT

    while lat <= MAX_LAT + 1e-9:

        # Approximately 11 km latitude spacing
        lat_step_km = 111.0 * GRID_LAT_STEP

        lon_degree_km = (
            111.0
            * math.cos(math.radians(lat))
        )

        lon_step = (
            lat_step_km
            / lon_degree_km
        )

        lon = MIN_LON

        while lon <= MAX_LON + 1e-9:

            points.append({
                "latitude": round(lat, 6),
                "longitude": round(lon, 6),
            })

            lon += lon_step

        lat += GRID_LAT_STEP

    return points


# Batch
def split_into_batches(
    points: List[Dict[str, float]],
    batch_size: int,
):

    for i in range(
        0,
        len(points),
        batch_size,
    ):
        yield points[
            i:i + batch_size
        ]


# Open-Meteo API
def query_open_meteo(
    points: List[Dict[str, float]],
) -> List[Dict]:

    params = {
        "latitude": ",".join(
            str(point["latitude"])
            for point in points
        ),

        "longitude": ",".join(
            str(point["longitude"])
            for point in points
        ),

        "hourly": ",".join(
            HOURLY_VARIABLES
        ),

        "forecast_hours": FORECAST_HOURS,

        "timezone": TIMEZONE,

        "cell_selection": CELL_SELECTION,
    }

    for attempt in range(
        1,
        MAX_RETRIES + 1,
    ):

        try:

            query_string = urllib.parse.urlencode(
                params
            )

            request_url = (
                f"{OPEN_METEO_URL}?{query_string}"
            )

            request = urllib.request.Request(
                request_url,
                method="GET",
            )

            with urllib.request.urlopen(
                request,
                timeout=60,
            ) as response:

                data = json.loads(
                    response.read().decode(
                        "utf-8"
                    )
                )

            if isinstance(data, list):
                return data

            return []

        except (
            urllib.error.URLError,
            urllib.error.HTTPError,
            TimeoutError,
        ) as e:

            print(
                f"Open-Meteo request failed "
                f"(attempt "
                f"{attempt}/{MAX_RETRIES}): "
                f"{e}"
            )

            if attempt < MAX_RETRIES:
                time.sleep(
                    RETRY_SLEEP_SECONDS
                )

    return []


# Safe value getter
def get_value(
    values: List,
    index: int,
):

    if index >= len(values):
        return None

    return values[index]


# Flatten
def flatten_location(
    location: Dict,
) -> List[Dict]:

    hourly = location.get(
        "hourly",
        {},
    )

    times = hourly.get(
        "time",
        [],
    )

    if not times:
        return []

    records = []

    for i, measurement_time in enumerate(
        times
    ):

        records.append({

            "source": "OPEN_METEO",

            "model_grid_latitude":
                location.get("latitude"),

            "model_grid_longitude":
                location.get("longitude"),

            "measurement_time":
                measurement_time,

            "pm25": get_value(
                hourly.get("pm2_5", []),
                i,
            ),

            "pm10": get_value(
                hourly.get("pm10", []),
                i,
            ),

            "no2": get_value(
                hourly.get(
                    "nitrogen_dioxide",
                    [],
                ),
                i,
            ),

            "o3": get_value(
                hourly.get(
                    "ozone",
                    [],
                ),
                i,
            ),

            "so2": get_value(
                hourly.get(
                    "sulphur_dioxide",
                    [],
                ),
                i,
            ),

            "co": get_value(
                hourly.get(
                    "carbon_monoxide",
                    [],
                ),
                i,
            ),
        })

    return records


# Build SQS message
def build_message(
    records: List[Dict],
) -> Dict:

    return {
        "source": "OPEN_METEO",

        "record_count": len(records),

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
        "Starting Open-Meteo collection..."
    )

    # 1. Generate sampling points
    points = generate_grid_points()

    print(
        f"Generated "
        f"{len(points)} sampling points"
    )

    # 2. Call Open-Meteo
    all_records = []

    batches = split_into_batches(
        points,
        BATCH_SIZE,
    )

    for batch_index, batch in enumerate(
        batches,
        start=1,
    ):

        print(
            f"Requesting batch "
            f"{batch_index} "
            f"({len(batch)} points)"
        )

        locations = query_open_meteo(
            batch
        )

        print(
            f"Received "
            f"{len(locations)} locations"
        )

        for location in locations:

            records = flatten_location(
                location
            )

            all_records.extend(
                records
            )

    print(
        f"Total records: "
        f"{len(all_records)}"
    )

    message = build_message(
        all_records
    )

    # 4. Send to SQS
    send_to_sqs(
        message
    )

    # 5. Lambda response
    return {
        "statusCode": 200,

        "source": "OPEN_METEO",

        "record_count": len(
            all_records
        ),
    }