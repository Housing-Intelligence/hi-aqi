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
