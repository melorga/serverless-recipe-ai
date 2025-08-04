"""
Lambda function for AI-powered recipe generation using Amazon Bedrock.
"""

import json
import os
import boto3
import uuid
from datetime import datetime
from typing import Dict, Any, Optional, List
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.utilities.typing import LambdaContext
from aws_lambda_powertools.logging import correlation_paths
from aws_lambda_powertools.metrics import MetricUnit

# Initialize powertools
logger = Logger()
tracer = Tracer()
metrics = Metrics()

# Initialize AWS clients
bedrock_runtime = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
dynamodb = boto3.resource('dynamodb', region_name=os.environ.get('AWS_REGION', 'us-east-1'))

# Environment variables
DYNAMODB_TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'recipe-ai-recipes')
BEDROCK_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')

# DynamoDB table
table = dynamodb.Table(DYNAMODB_TABLE_NAME)


class RecipeGenerator:
    """Recipe generation using Amazon Bedrock."""
    
    def __init__(self):
        self.model_id = BEDROCK_MODEL_ID
    
    @tracer.capture_method
    def generate_recipe(self, ingredients: List[str], dietary_restrictions: List[str] = None,
                       cuisine_type: str = None, meal_type: str = None, 
                       difficulty: str = "medium") -> Dict[str, Any]:
        """Generate a recipe using Amazon Bedrock."""
        
        # Build the prompt
        prompt = self._build_prompt(ingredients, dietary_restrictions, cuisine_type, meal_type, difficulty)
        
        # Prepare the request body for Bedrock
        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2000,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.7,
            "top_p": 0.9
        }
        
        try:
            # Call Bedrock
            response = bedrock_runtime.invoke_model(
                modelId=self.model_id,
                contentType='application/json',
                accept='application/json',
                body=json.dumps(request_body)
            )
            
            # Parse response
            response_body = json.loads(response['body'].read())
            generated_text = response_body['content'][0]['text']
            
            # Parse the generated recipe
            recipe = self._parse_recipe_response(generated_text)
            
            metrics.add_metric(name="RecipeGenerated", unit=MetricUnit.Count, value=1)
            
            return recipe
            
        except Exception as e:
            logger.error(f"Error generating recipe: {str(e)}")
            metrics.add_metric(name="RecipeGenerationError", unit=MetricUnit.Count, value=1)
            raise
    
    def _build_prompt(self, ingredients: List[str], dietary_restrictions: List[str] = None,
                     cuisine_type: str = None, meal_type: str = None, 
                     difficulty: str = "medium") -> str:
        """Build the prompt for recipe generation."""
        
        ingredients_str = ", ".join(ingredients)
        
        prompt = f"""Generate a detailed recipe using the following ingredients: {ingredients_str}

Requirements:
- Difficulty level: {difficulty}
"""
        
        if dietary_restrictions:
            restrictions_str = ", ".join(dietary_restrictions)
            prompt += f"- Dietary restrictions: {restrictions_str}\n"
        
        if cuisine_type:
            prompt += f"- Cuisine type: {cuisine_type}\n"
        
        if meal_type:
            prompt += f"- Meal type: {meal_type}\n"
        
        prompt += """
Please provide the recipe in the following JSON format:
{
    "title": "Recipe Name",
    "description": "Brief description of the dish",
    "prep_time": "15 minutes",
    "cook_time": "30 minutes",
    "total_time": "45 minutes",
    "servings": 4,
    "difficulty": "medium",
    "cuisine": "cuisine type",
    "ingredients": [
        {
            "item": "ingredient name",
            "amount": "1 cup",
            "notes": "optional preparation notes"
        }
    ],
    "instructions": [
        "Step 1: Detailed instruction",
        "Step 2: Another detailed instruction"
    ],
    "nutrition": {
        "calories": 350,
        "protein": "25g",
        "carbs": "30g",
        "fat": "15g"
    },
    "tags": ["tag1", "tag2", "tag3"],
    "tips": ["Cooking tip 1", "Cooking tip 2"]
}

Please ensure all ingredients from the input list are used in the recipe where possible.
"""
        
        return prompt
    
    def _parse_recipe_response(self, response_text: str) -> Dict[str, Any]:
        """Parse the AI response into a structured recipe."""
        
        try:
            # Find JSON in the response
            start_idx = response_text.find('{')
            end_idx = response_text.rfind('}') + 1
            
            if start_idx == -1 or end_idx == 0:
                raise ValueError("No JSON found in response")
            
            json_str = response_text[start_idx:end_idx]
            recipe = json.loads(json_str)
            
            # Add metadata
            recipe['id'] = str(uuid.uuid4())
            recipe['created_at'] = datetime.utcnow().isoformat()
            recipe['source'] = 'ai_generated'
            
            return recipe
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse recipe JSON: {str(e)}")
            # Return a fallback recipe structure
            return self._create_fallback_recipe(response_text)
        except Exception as e:
            logger.error(f"Error parsing recipe response: {str(e)}")
            raise
    
    def _create_fallback_recipe(self, response_text: str) -> Dict[str, Any]:
        """Create a fallback recipe structure when JSON parsing fails."""
        
        return {
            'id': str(uuid.uuid4()),
            'title': 'AI Generated Recipe',
            'description': 'Recipe generated by AI',
            'prep_time': '20 minutes',
            'cook_time': '30 minutes',
            'total_time': '50 minutes',
            'servings': 4,
            'difficulty': 'medium',
            'cuisine': 'various',
            'ingredients': [],
            'instructions': [response_text],
            'nutrition': {},
            'tags': ['ai-generated'],
            'tips': [],
            'created_at': datetime.utcnow().isoformat(),
            'source': 'ai_generated'
        }


@tracer.capture_lambda_handler
@logger.inject_lambda_context(correlation_id_path=correlation_paths.API_GATEWAY_REST)
@metrics.log_metrics
def lambda_handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    """Lambda handler for recipe generation."""
    
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        
        # Extract parameters
        ingredients = body.get('ingredients', [])
        dietary_restrictions = body.get('dietary_restrictions', [])
        cuisine_type = body.get('cuisine_type')
        meal_type = body.get('meal_type')
        difficulty = body.get('difficulty', 'medium')
        save_to_db = body.get('save_to_db', True)
        
        # Validate inputs
        if not ingredients:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                    'Access-Control-Allow-Methods': 'POST,OPTIONS'
                },
                'body': json.dumps({
                    'error': 'Ingredients list is required'
                })
            }
        
        logger.info(f"Generating recipe with ingredients: {ingredients}")
        
        # Generate recipe
        generator = RecipeGenerator()
        recipe = generator.generate_recipe(
            ingredients=ingredients,
            dietary_restrictions=dietary_restrictions,
            cuisine_type=cuisine_type,
            meal_type=meal_type,
            difficulty=difficulty
        )
        
        # Save to DynamoDB if requested
        if save_to_db:
            try:
                table.put_item(Item=recipe)
                logger.info(f"Recipe saved to DynamoDB with ID: {recipe['id']}")
                metrics.add_metric(name="RecipeSaved", unit=MetricUnit.Count, value=1)
            except Exception as e:
                logger.error(f"Failed to save recipe to DynamoDB: {str(e)}")
                # Don't fail the request if DB save fails
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps(recipe)
        }
        
    except Exception as e:
        logger.error(f"Error in lambda handler: {str(e)}")
        metrics.add_metric(name="LambdaError", unit=MetricUnit.Count, value=1)
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps({
                'error': 'Internal server error'
            })
        }
