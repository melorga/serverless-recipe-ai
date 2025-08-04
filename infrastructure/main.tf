terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "serverless-recipe-ai"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "serverless-recipe-ai"
    }
  }
}

locals {
  function_name = "${var.environment}-recipe-generator"
  
  common_tags = {
    Project     = "serverless-recipe-ai"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# DynamoDB table for caching recipes
resource "aws_dynamodb_table" "recipe_cache" {
  name           = "${var.environment}-recipe-cache"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "cache_key"
  stream_enabled = false

  attribute {
    name = "cache_key"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}

# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for Lambda function
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.function_name}-policy"
  role = aws_iam_role.lambda_role.id

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
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.recipe_cache.arn
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.environment == "prod" ? 30 : 7
  
  tags = local.common_tags
}

# Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend"
  output_path = "${path.module}/lambda_function.zip"
  excludes    = ["__pycache__", "*.pyc", "tests", "venv"]
}

resource "aws_lambda_function" "recipe_generator" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = local.function_name
  role            = aws_iam_role.lambda_role.arn
  handler         = "generate-recipe.lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 512

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.recipe_cache.name
      ENVIRONMENT    = var.environment
      BEDROCK_MODEL  = "anthropic.claude-3-sonnet-20240229-v1:0"
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = local.common_tags
}

# API Gateway
resource "aws_api_gateway_rest_api" "recipe_api" {
  name        = "${var.environment}-recipe-api"
  description = "Serverless Recipe Generator API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

# API Gateway Resource
resource "aws_api_gateway_resource" "recipes" {
  rest_api_id = aws_api_gateway_rest_api.recipe_api.id
  parent_id   = aws_api_gateway_rest_api.recipe_api.root_resource_id
  path_part   = "recipes"
}

# API Gateway Method
resource "aws_api_gateway_method" "recipes_post" {
  rest_api_id   = aws_api_gateway_rest_api.recipe_api.id
  resource_id   = aws_api_gateway_resource.recipes.id
  http_method   = "POST"
  authorization = "NONE"
  
  request_validator_id = aws_api_gateway_request_validator.recipe_validator.id
  
  request_models = {
    "application/json" = aws_api_gateway_model.recipe_request.name
  }
}

# Request Validator
resource "aws_api_gateway_request_validator" "recipe_validator" {
  name                        = "${var.environment}-recipe-validator"
  rest_api_id                = aws_api_gateway_rest_api.recipe_api.id
  validate_request_body      = true
  validate_request_parameters = true
}

# Request Model
resource "aws_api_gateway_model" "recipe_request" {
  rest_api_id  = aws_api_gateway_rest_api.recipe_api.id
  name         = "RecipeRequest"
  content_type = "application/json"

  schema = jsonencode({
    type = "object"
    required = ["ingredients"]
    properties = {
      ingredients = {
        type = "array"
        items = {
          type = "string"
        }
        minItems = 1
        maxItems = 10
      }
      cuisine = {
        type = "string"
        enum = ["italian", "mexican", "indian", "chinese", "japanese", "french", "american", "mediterranean"]
      }
      dietary_restrictions = {
        type = "array"
        items = {
          type = "string"
          enum = ["vegetarian", "vegan", "gluten-free", "dairy-free", "keto", "paleo"]
        }
      }
      serving_size = {
        type = "integer"
        minimum = 1
        maximum = 12
      }
    }
  })
}

# API Gateway Integration
resource "aws_api_gateway_integration" "recipes_post" {
  rest_api_id = aws_api_gateway_rest_api.recipe_api.id
  resource_id = aws_api_gateway_resource.recipes.id
  http_method = aws_api_gateway_method.recipes_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.recipe_generator.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.recipe_generator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.recipe_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "recipe_api" {
  depends_on = [
    aws_api_gateway_method.recipes_post,
    aws_api_gateway_integration.recipes_post
  ]

  rest_api_id = aws_api_gateway_rest_api.recipe_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.recipes.id,
      aws_api_gateway_method.recipes_post.id,
      aws_api_gateway_integration.recipes_post.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "recipe_api" {
  deployment_id = aws_api_gateway_deployment.recipe_api.id
  rest_api_id   = aws_api_gateway_rest_api.recipe_api.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      responseTime   = "$context.responseTime"
      error          = "$context.error.message"
    })
  }

  tags = local.common_tags
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.recipe_api.name}"
  retention_in_days = var.environment == "prod" ? 30 : 7
  
  tags = local.common_tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "recipe_api" {
  dashboard_name = "${var.environment}-recipe-api-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.recipe_generator.function_name],
            [".", "Errors", ".", "."],
            [".", "Invocations", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Function Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.recipe_api.name],
            [".", "Latency", ".", "."],
            [".", "4XXError", ".", "."],
            [".", "5XXError", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Metrics"
          period  = 300
        }
      }
    ]
  })
}
