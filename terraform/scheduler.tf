resource "aws_scheduler_schedule" "aqicn_hourly"{
    flexible_time_window {
        mode = "OFF"
    }
    schedule_expression = "rate(1 hour)"
    target {
        arn = aws_lambda_function.aqicn.arn
        role_arn = ""
    }
}

resource "aws_scheduler_schedule" "meteo_hourly"{
    flexible_time_window {
        mode = "OFF"
    }
    schedule_expression = "rate(1 hour)"
    target {
        arn = aws_lambda_function.meteo.arn
        role_arn = ""
    }
}

