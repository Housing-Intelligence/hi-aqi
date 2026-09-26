# Lambda Assume Role Policy
data "aws_iam_policy_document" "lambda_assume_role" {

  statement {
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

# AQICN Lambda Role
resource "aws_iam_role" "aqicn_lambda" {

  name = "housing-air-quality-aqicn-lambda-role"

  assume_role_policy = (
    data.aws_iam_policy_document.lambda_assume_role.json
  )
}

# AQICN Lambda Permissions
resource "aws_iam_role_policy" "aqicn_lambda" {

  name = "housing-air-quality-aqicn-lambda-policy"

  role = aws_iam_role.aqicn_lambda.id

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "*"
      },

      {
        Effect = "Allow"

        Action = [
          "sqs:SendMessage"
        ]

        Resource = aws_sqs_queue.air_quality.arn
      },

      {
        Effect = "Allow"

        Action = [
            "ssm:GetParameter"
        ]

        Resource = aws_ssm_parameter.waqi_token.arn
      }
    ]
  })
}

# Meteo Lambda Role
resource "aws_iam_role" "meteo_lambda" {

  name = "housing-air-quality-meteo-lambda-role"

  assume_role_policy = (
    data.aws_iam_policy_document.lambda_assume_role.json
  )
}

# Meteo Lambda Permissions
resource "aws_iam_role_policy" "meteo_lambda" {

  name = "housing-air-quality-meteo-lambda-policy"

  role = aws_iam_role.meteo_lambda.id

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "*"
      },

      # Send message to SQS
      {
        Effect = "Allow"

        Action = [
          "sqs:SendMessage"
        ]

        Resource = aws_sqs_queue.air_quality.arn
      }
    ]
  })
}

data "aws_s3_bucket" "air_quality" {
  bucket = var.s3_bucket
}

resource "aws_iam_role" "aggregator_lambda" {
  name = "housing-air-quality-aggregator-lambda-role"

  assume_role_policy = (
    data.aws_iam_policy_document.lambda_assume_role.json
  )
}

resource "aws_iam_role_policy" "aggregator_lambda" {
    name = "housing-air-quality-aggregator-lambda-policy"

    role = aws_iam_role.aggregator_lambda.id

    policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "*"
      },

      # Get message from SQS
      {
        Effect = "Allow"

        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]

        Resource = aws_sqs_queue.air_quality.arn
      },

      # Save message to S3
      {
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = "${data.aws_s3_bucket.air_quality.arn}/raw_data/public_data/*"
      }
    ]
  })
}


# EventBridge Scheduler Assume Role
data "aws_iam_policy_document" "scheduler_assume_role" {

  statement {

    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "scheduler.amazonaws.com"
      ]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

# Scheduler Role
resource "aws_iam_role" "scheduler" {

  name = "housing-air-quality-scheduler-role"

  assume_role_policy = (
    data.aws_iam_policy_document.scheduler_assume_role.json
  )
}

# Scheduler Permissions
resource "aws_iam_role_policy" "scheduler" {

  name = "housing-air-quality-scheduler-policy"

  role = aws_iam_role.scheduler.id

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Action = [
          "lambda:InvokeFunction"
        ]

        Resource = [
          aws_lambda_function.aqicn.arn,
          aws_lambda_function.meteo.arn
        ]
      }
    ]
  })
}