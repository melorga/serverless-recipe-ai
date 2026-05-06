"""Shared pytest fixtures and path setup."""

import os
import sys
from pathlib import Path

# Make the lambda package importable as ``lambda_function``.
LAMBDA_DIR = Path(__file__).resolve().parents[1] / "backend" / "generate-recipe"
sys.path.insert(0, str(LAMBDA_DIR))

# Default env so importing the module does not blow up on AWS client init.
os.environ.setdefault("AWS_REGION", "us-east-1")
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
os.environ.setdefault("DYNAMODB_TABLE_NAME", "test-recipe-cache")
