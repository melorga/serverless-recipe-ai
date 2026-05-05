# Serverless Recipe AI

> **Status:** single-Lambda portfolio demo. One Python Lambda behind API
> Gateway, DynamoDB for caching, Amazon Bedrock for generation. There is
> no frontend, no Cognito, no multi-service backend in this repo.

An AI-powered recipe generator built on AWS serverless primitives.

## Architecture

```
Client --(HTTPS, x-api-key)--> API Gateway (REST)
                                     |
                                     v
                           Lambda (Python 3.13)
                                /          \
                               v            v
                         DynamoDB       Amazon Bedrock
                         (cache)        (Claude Haiku 4.5)
```

- **API**: Amazon API Gateway (REST), API key + usage plan auth.
- **Compute**: One AWS Lambda (`generate-recipe`), Python 3.13, AWS Lambda
  Powertools, X-Ray tracing.
- **AI**: Amazon Bedrock - default model
  `anthropic.claude-haiku-4-5-20251001-v1:0`, override with the
  `bedrock_model_id` Terraform variable. Bedrock model ids follow the
  format `anthropic.<api-name>-<release-date>-v<n>:0` - the bare
  `anthropic.claude-haiku-4-5` will not resolve at `InvokeModel`.
- **Storage**: DynamoDB (`PAY_PER_REQUEST`, TTL enabled).
- **Observability**: CloudWatch Logs, CloudWatch Dashboard, X-Ray.
- **IaC**: Terraform (>= 1.9, AWS provider ~> 6.0).

## Project Structure

```
serverless-recipe-ai/
|-- backend/
|   `-- generate-recipe/
|       |-- lambda_function.py
|       `-- requirements.txt
|-- infrastructure/        # Terraform
|   |-- versions.tf
|   |-- variables.tf
|   |-- main.tf
|   `-- outputs.tf
|-- tests/                 # pytest suite
|   |-- conftest.py
|   |-- test_lambda_function.py
|   `-- requirements.txt
|-- .github/
|   |-- workflows/ci.yml
|   `-- dependabot.yml
|-- Makefile
|-- CODEOWNERS
|-- SECURITY.md
`-- README.md
```

## Prerequisites

- AWS account with Bedrock model access enabled for the chosen model id.
- AWS CLI v2, configured.
- Terraform >= 1.9, < 2.0.
- Python 3.13.

## Deploy

```bash
# 1. Provision infra (creates DynamoDB, IAM, Lambda, API Gateway, API key).
make deploy-infra ENV=dev

# 2. (Re)package the Lambda zip; Terraform handles the upload via archive_file.
make deploy-backend
```

To override the Bedrock model (use the canonical `<api-name>-<release-date>-v<n>:0`
format):

```bash
cd infrastructure
terraform apply -var="bedrock_model_id=anthropic.claude-sonnet-4-5-20250929-v1:0"
```

## Calling the API

The `POST /recipes` endpoint requires the `x-api-key` header. Retrieve the
key value (Terraform only outputs the id):

```bash
KEY_ID=$(terraform -chdir=infrastructure output -raw api_key_id)
API_KEY=$(aws apigateway get-api-key --api-key "$KEY_ID" --include-value --query value --output text)
INVOKE_URL=$(terraform -chdir=infrastructure output -raw api_gateway_invoke_url)

curl -X POST "$INVOKE_URL/recipes" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
        "ingredients": ["chicken", "rice", "lemon"],
        "cuisine": "mediterranean",
        "dietary_restrictions": ["gluten-free"],
        "serving_size": 4
      }'
```

## Lambda environment variables

| Name                 | Purpose                                                    | Default                                       |
| -------------------- | ---------------------------------------------------------- | --------------------------------------------- |
| `BEDROCK_MODEL_ID`   | Bedrock foundation model id.                               | `anthropic.claude-haiku-4-5-20251001-v1:0`    |
| `DYNAMODB_TABLE_NAME`| DynamoDB cache table name.                                 | set by Terraform                              |
| `ALLOWED_ORIGIN`     | Value used for `Access-Control-Allow-Origin` response hdr. | `*`                                           |
| `ENVIRONMENT`        | `dev` / `stage` / `prod` for log retention etc.            | `dev`                                         |

## Tests

```bash
make test
```

The suite imports the Lambda module directly and asserts behaviour
without hitting AWS. The default model id assertion is a regression
guard against re-introducing deprecated Claude 3 Sonnet.

## Security notes

- API key + usage plan provides quota and throttle, not identity. For a
  real product, swap in Cognito or a JWT authorizer.
- Lambda execution role is scoped to the specific Bedrock model ARN, the
  one DynamoDB table, and X-Ray.
- CloudWatch log retention is 30 days for `prod`, 7 days otherwise.

See `SECURITY.md` for how to report vulnerabilities.

## License

MIT - see `LICENSE`.
