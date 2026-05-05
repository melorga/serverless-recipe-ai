variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, prod."
  }
}

variable "domain_name" {
  description = "Custom domain name for the API (optional)"
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain (required if domain_name is set)"
  type        = string
  default     = null
}

variable "bedrock_model_id" {
  description = "Amazon Bedrock foundation model id used by the Lambda."
  type        = string
  default     = "anthropic.claude-haiku-4-5"
}

variable "allowed_origin" {
  description = "Value used for the Access-Control-Allow-Origin response header. Defaults to '*' for dev; set to your frontend origin in production."
  type        = string
  default     = "*"
}

variable "api_quota_limit" {
  description = "Monthly API quota for the default usage plan."
  type        = number
  default     = 1000
}

variable "api_throttle_rate_limit" {
  description = "Steady-state requests per second for the default usage plan."
  type        = number
  default     = 5
}

variable "api_throttle_burst_limit" {
  description = "Burst requests for the default usage plan."
  type        = number
  default     = 10
}
