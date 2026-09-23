data "archive_file" "aqicn" {
  type = "zip"

  source_file = "${path.module}/lambda/aqicn/lambda_function.py"

  output_path = "${path.module}/aqicn.zip"
}

data "archive_file" "meteo" {
  type = "zip"

  source_file = "${path.module}/lambda/meteo/lambda_function.py"

  output_path = "${path.module}/meteo.zip"
}

data "archive_file" "aggregator" {
  type = "zip"

  source_file = "${path.module}/lambda/aggregator/lambda_function.py"

  output_path = "${path.module}/aggregator.zip"
}

resource "aws_lambda_function" "aqicn"  {
    function_name = "housing-air-quality-aqicn"
    filename = data.archive_file.aqicn.output_path
    source_code_hash = data.archive_file.aqicn.output_base64sha256
    role = ""
    handlder = "lambda_function.lambda_handler"
}

resource "aws_lambda_function" "meteo" {
  function_name = "housing-air-quality-meteo"
  filename = data.archive_file.meteo.output_path
  source_code_hash = data.archive_file.meteo.output_base64sha256
  role = ""
  handlder = "lambda_function.lambda_handler"
  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.air_quality.url
    }
  }
}