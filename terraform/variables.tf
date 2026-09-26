variable aws_region {
  type        = string
  default     = ""
}

variable "s3_bucket" {
  type        = string
  default     = "housing-intelligence-data"
  description = "s3 bucket to store the messages"
}

variable "waqi_secret" {
  type = string
  description = "api key for the waqi"
  sensitive = true
}

resource "aws_ssm_parameter" "waqi_token" {
  name  = "/housing/air-quality/waqi-token"
  type  = "SecureString"
  value = var.waqi_secret
  tier  = "Standard"
}