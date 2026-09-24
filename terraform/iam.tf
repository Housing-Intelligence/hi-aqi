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