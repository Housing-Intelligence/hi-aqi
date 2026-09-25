resource "aws_scheduler_schedule" "aqicn_hourly"{
    flexible_time_window {
        mode = "OFF"
    }
    schedule_expression = "cron(0 * * * ? *)"
    target {
        arn = aws_lambda_function.aqicn.arn
        role_arn = aws_iam_role.scheduler.arn
    }
}

resource "aws_scheduler_schedule" "meteo_hourly"{
    flexible_time_window {
        mode = "OFF"
    }
    schedule_expression = "cron(0 * * * ? *)"
    target {
        arn = aws_lambda_function.meteo.arn
        role_arn = aws_iam_role.scheduler.arn
    }
}

