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