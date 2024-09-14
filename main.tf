provider "aws" {
  region = "ap-southeast-1"
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Role Policy for Lambda Function (CloudWatch Logs and API Gateway Access)
resource "aws_iam_role_policy" "lambda_exec_policy" {
  name   = "lambda_exec_policy"
  role   = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = "lambda:InvokeFunction",
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Lambda Function (Updated name to saveContactMeNow)
resource "aws_lambda_function" "save_contact_me_now" {
  function_name = "saveContactMeNow"  # Updated function name
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "lambda.zip"

  environment {
    variables = {
      ENV = "v1"
    }
  }
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "portfolio" {
  name        = "Portfolio"
  description = "API Gateway for processing contact form submissions."
}

# API Gateway Resource for /contactme
resource "aws_api_gateway_resource" "contactme" {
  rest_api_id = aws_api_gateway_rest_api.portfolio.id
  parent_id   = aws_api_gateway_rest_api.portfolio.root_resource_id
  path_part   = "contactme"
}

# POST Method for /contactme resource
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.portfolio.id
  resource_id   = aws_api_gateway_resource.contactme.id
  http_method   = "POST"
  authorization = "NONE"
  
  request_models = {
    "application/json" = aws_api_gateway_model.contact_me_model.name
  }
  
}

# Integration of API Gateway and Lambda Function (Updated to new function)
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.portfolio.id
  resource_id             = aws_api_gateway_resource.contactme.id
  http_method             = aws_api_gateway_method.post_method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.save_contact_me_now.invoke_arn
  
  # Mapping templates
  request_templates = {
    "application/json" = null
  }
}

# Enable CORS for the /contactme resource
resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.portfolio.id
  resource_id = aws_api_gateway_resource.contactme.id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
}
response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
}
}

resource "aws_api_gateway_integration_response" "post_response" {
  depends_on = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.portfolio.id
  resource_id = aws_api_gateway_resource.contactme.id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods"     = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"      = "'*'",
  }
}

# Deploy API Gateway
resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
  ]
  rest_api_id = aws_api_gateway_rest_api.portfolio.id
  stage_name  = "v1"
}

# Lambda permission to be invoked by API Gateway (Updated function name)
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.save_contact_me_now.function_name  # Updated function name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.portfolio.execution_arn}/*/*"
}

# DynamoDB Table for ContactMessages (Updated name to ContactMeMessages)
resource "aws_dynamodb_table" "contact_messages" {
  name           = "ContactMeMessages"  # Updated DynamoDB table name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "MessageId"
  
  attribute {
    name = "MessageId"
    type = "S"
  }

  tags = {
    Name = "ContactMeMessagesTable"
  }
}

# IAM Role Policy for Terraform (DynamoDB PutItem)
resource "aws_iam_role_policy" "terraform_dynamodb" {
  name   = "terraform_dynamodb"
  role   = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:PutItem"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:dynamodb:*:*:table/ContactMeMessages"
      }
    ]
  })
}

# API Gateway Model for Request Validation
resource "aws_api_gateway_model" "contact_me_model" {
  rest_api_id  = aws_api_gateway_rest_api.portfolio.id
  name         = "ContactMeModel"
  content_type = "application/json"
  schema       = jsonencode({
    type = "object",
    properties = {
      messageId = {
        type      = "string",
        minLength = 1,
        maxLength = 100
      },
      name = {
        type      = "string",
        minLength = 1,
        maxLength = 100
      },
      email = {
        type      = "string",
        format    = "email",
        minLength = 1,
        maxLength = 100
      },
      subject = {
        type      = "string",
        minLength = 1,
        maxLength = 200
      },
      message = {
        type      = "string",
        minLength = 1,
        maxLength = 1000
      }
    },
    required     = ["messageId", "name", "email", "subject", "message"],
    additionalProperties = false
  })
}


