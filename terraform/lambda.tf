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
    role = aws_iam_role.aqicn_lambda.arn
    handler = "lambda_function.lambda_handler"
    runtime = "python3.13"
    timeout     = 30
    environment {
      variables = {
        SQS_QUEUE_URL = aws_sqs_queue.air_quality.url
        AQICN_TOKEN = var.waqi_secret
      }
    }
}

resource "aws_lambda_function" "meteo" {
  function_name = "housing-air-quality-meteo"
  filename = data.archive_file.meteo.output_path
  source_code_hash = data.archive_file.meteo.output_base64sha256
  role = aws_iam_role.meteo_lambda.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"
  timeout     = 30
  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.air_quality.url
    }
  }
}

resource "aws_lambda_function" "aggregator" {
  function_name = "housing-air-quality-aggregator"

  filename         = data.archive_file.aggregator.output_path
  source_code_hash = data.archive_file.aggregator.output_base64sha256

  role    = aws_iam_role.aggregator_lambda.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

  timeout     = 30

  environment {
    variables = {
      S3_BUCKET = var.s3_bucket
    }
  }
}

resource "aws_lambda_event_source_mapping" "air_quality" {
  event_source_arn = aws_sqs_queue.air_quality.arn
  function_name    = aws_lambda_function.aggregator.arn

  batch_size = 1
  enabled    = true
}