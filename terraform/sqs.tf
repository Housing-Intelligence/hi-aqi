resource "aws_sqs_queue" "air_quality_dlq" {
  name = "housing-air-quality-ingestion-dlq"
}

resource "aws_sqs_queue" "air_quality" {
  name = "housing-air-quality-ingestion"

  visibility_timeout_seconds = 360

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.air_quality_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_lambda_event_source_mapping" "air_quality" {
  event_source_arn = aws_sqs_queue.air_quality.arn
  function_name    = aws_lambda_function.aggregator.arn

  batch_size = 1
  enabled    = true
}