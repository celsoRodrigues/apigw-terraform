resource "aws_iam_role" "role_for_lambda" {

  name = "iam_for_lambda"

  assume_role_policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ] 
      }, 
      "Effect": "Allow"
      "Sid": "accessToRole"
    }
  ]
})

 tags = {
  tag-key = "role-for-hello-lambda"
 }
}

resource "aws_iam_role_policy" "role_policy_lambda" {

  name = "default_role_policy"
  role = aws_iam_role.role_for_lambda.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:eu-west-1:973779978997:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:eu-west-1:973779978997:log-group:/aws/lambda/hello-golang:*"
            ]
        }
    ]
}
EOF
}

resource "aws_lambda_function" "test_lambda_func" {
  function_name     = "lambda-function-hello"
  handler           = "hello"
  runtime           = "go1.x"
  role              =  aws_iam_role.role_for_lambda.arn
  filename          = "./lambda/workload/hello.zip"
  source_code_hash  = filebase64sha256("./lambda/workload/hello.zip")
  memory_size       = 128
  timeout           = 10
}

resource "aws_lambda_function" "auth_lambda_func" {
  function_name     = "auth-function"
  handler           = "auth"
  runtime           = "go1.x"
  role              =  aws_iam_role.role_for_lambda.arn
  filename          = "./lambda/auth/auth.zip"
  source_code_hash  = filebase64sha256("./lambda/auth/auth.zip")
  memory_size       = 128
  timeout           = 10
}


resource "aws_lambda_permission" "allow_test" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda_func.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_lambda_permission" "allow_auth" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_lambda_func.function_name
  principal     = "apigateway.amazonaws.com"
}



######## API GW ####################


resource "aws_api_gateway_rest_api" "api_gateway" {
  name = "test-api-gateway"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "person" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "person"
}


// POST
resource "aws_api_gateway_method" "post" {
  rest_api_id       = aws_api_gateway_rest_api.api_gateway.id
  resource_id       = aws_api_gateway_resource.person.id
  http_method       = "POST"
  authorization     = "NONE"
  api_key_required  = false
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.person.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.test_lambda_func.invoke_arn
}


// GET
resource "aws_api_gateway_method" "get" {
  rest_api_id       = aws_api_gateway_rest_api.api_gateway.id
  resource_id       = aws_api_gateway_resource.person.id
  http_method       = "GET"
  authorization     = "CUSTOM"
  authorizer_id     = aws_api_gateway_authorizer.authorizer_resource.id
  api_key_required  = false
}

resource "aws_api_gateway_integration" "integration-get" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.person.id
  http_method             = aws_api_gateway_method.get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.test_lambda_func.invoke_arn
}

################ AUTH ####################################


resource "aws_api_gateway_authorizer" "authorizer_resource" {
  name                   = "auth_resource"
  rest_api_id            = aws_api_gateway_rest_api.api_gateway.id
  authorizer_uri         = aws_lambda_function.auth_lambda_func.invoke_arn
  authorizer_credentials = aws_iam_role.auth_invocation_role.arn
}

resource "aws_iam_role" "auth_invocation_role" {
  name = "api_gateway_auth_invocation"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "invocation_policy" {
  name = "default_invocation_policy"
  role = aws_iam_role.auth_invocation_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.auth_lambda_func.arn}"
    }
  ]
}
EOF
}


################ Deployment of API gateway ################


resource "aws_api_gateway_deployment" "deployment1" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id


  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api_gateway.body))
  }


  depends_on = [aws_api_gateway_integration.integration]
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.deployment1.id
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  stage_name    = "latest"
}
