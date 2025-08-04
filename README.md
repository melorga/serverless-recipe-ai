# Serverless Recipe AI

An AI-powered recipe recommendation system built with AWS serverless technologies.

## Architecture

- **Frontend**: React web application hosted on S3/CloudFront
- **API**: AWS API Gateway with Lambda functions
- **AI/ML**: Amazon Bedrock for recipe generation
- **Database**: DynamoDB for storing recipes and user preferences
- **Authentication**: Amazon Cognito
- **Infrastructure**: Terraform for Infrastructure as Code

## Features

- 🤖 AI-powered recipe generation using Amazon Bedrock
- 📱 Responsive web interface
- 🔍 Recipe search and filtering
- 💾 Save favorite recipes
- 👤 User authentication and profiles
- 🏷️ Ingredient-based recommendations
- 📊 Analytics and usage tracking

## Project Structure

```
serverless-recipe-ai/
├── infrastructure/          # Terraform configurations
│   ├── api-gateway/
│   ├── lambda/
│   ├── dynamodb/
│   └── cognito/
├── backend/                 # Lambda functions
│   ├── get-recipes/
│   ├── generate-recipe/
│   ├── save-recipe/
│   └── user-preferences/
├── frontend/                # React application
│   ├── src/
│   ├── public/
│   └── package.json
├── tests/                   # Test files
└── docs/                    # Documentation
```

## Tech Stack

### Backend
- **Runtime**: Python 3.11
- **Framework**: AWS Lambda with Powertools
- **AI/ML**: Amazon Bedrock (Claude/Titan models)
- **Database**: Amazon DynamoDB
- **API**: Amazon API Gateway (REST)
- **Auth**: Amazon Cognito

### Frontend
- **Framework**: React 18 with TypeScript
- **Styling**: Tailwind CSS
- **State Management**: React Query + Context API
- **Build Tool**: Vite
- **Deployment**: AWS S3 + CloudFront

### Infrastructure
- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **Monitoring**: CloudWatch + X-Ray

## Getting Started

### Prerequisites

- AWS CLI configured
- Terraform >= 1.5.7
- Node.js >= 18
- Python 3.11

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/melorga/serverless-recipe-ai.git
   cd serverless-recipe-ai
   ```

2. **Deploy infrastructure**
   ```bash
   cd infrastructure
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy backend functions**
   ```bash
   cd ../backend
   # Install dependencies and deploy
   make deploy
   ```

4. **Start frontend development server**
   ```bash
   cd ../frontend
   npm install
   npm run dev
   ```

## API Endpoints

- `GET /recipes` - List recipes with filtering
- `POST /recipes/generate` - Generate new recipe with AI
- `POST /recipes` - Save a recipe
- `DELETE /recipes/{id}` - Delete a recipe
- `GET /user/preferences` - Get user preferences
- `PUT /user/preferences` - Update user preferences

## Environment Variables

### Backend
- `BEDROCK_MODEL_ID` - Amazon Bedrock model identifier
- `DYNAMODB_TABLE_NAME` - DynamoDB table name
- `COGNITO_USER_POOL_ID` - Cognito User Pool ID

### Frontend
- `VITE_API_GATEWAY_URL` - API Gateway endpoint
- `VITE_COGNITO_USER_POOL_ID` - Cognito User Pool ID
- `VITE_COGNITO_CLIENT_ID` - Cognito Client ID

## Testing

```bash
# Backend tests
cd backend
python -m pytest

# Frontend tests
cd frontend
npm test

# Integration tests
make test-integration
```

## Deployment

The project uses GitHub Actions for CI/CD:

1. **Push to main branch** triggers production deployment
2. **Pull requests** trigger staging environment deployment
3. **Infrastructure changes** are planned and applied automatically

## Monitoring

- **CloudWatch Logs** for Lambda function logs
- **X-Ray Tracing** for distributed tracing
- **CloudWatch Metrics** for API and function metrics
- **DynamoDB Metrics** for database performance

## Cost Optimization

- DynamoDB On-Demand billing
- Lambda Provisioned Concurrency only for production
- CloudFront caching for static assets
- S3 Intelligent Tiering

## Security

- Cognito authentication for all API endpoints
- IAM roles with least privilege principles
- VPC Lambda functions for enhanced security
- Encryption at rest and in transit

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License.
