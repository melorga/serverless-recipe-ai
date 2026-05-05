"""Tests for backend/generate-recipe/lambda_function.py.

These deliberately avoid invoking AWS; they exercise pure-Python helpers and
guard against regressions of the deprecated Claude 3 Sonnet model id.
"""

import importlib
import json


def _reload():
    import lambda_function

    return importlib.reload(lambda_function)


def test_default_bedrock_model_id_is_haiku_4_5(monkeypatch):
    monkeypatch.delenv("BEDROCK_MODEL_ID", raising=False)
    mod = _reload()
    assert mod.BEDROCK_MODEL_ID == "anthropic.claude-haiku-4-5"
    # Regression: must not fall back to the deprecated model.
    assert "claude-3-sonnet-20240229" not in mod.BEDROCK_MODEL_ID


def test_bedrock_model_id_overridable(monkeypatch):
    monkeypatch.setenv("BEDROCK_MODEL_ID", "anthropic.claude-sonnet-4-5")
    mod = _reload()
    assert mod.BEDROCK_MODEL_ID == "anthropic.claude-sonnet-4-5"


def test_allowed_origin_default_is_wildcard(monkeypatch):
    monkeypatch.delenv("ALLOWED_ORIGIN", raising=False)
    mod = _reload()
    assert mod.RESPONSE_HEADERS["Access-Control-Allow-Origin"] == "*"


def test_allowed_origin_respects_env(monkeypatch):
    monkeypatch.setenv("ALLOWED_ORIGIN", "https://example.com")
    mod = _reload()
    assert mod.RESPONSE_HEADERS["Access-Control-Allow-Origin"] == "https://example.com"


def test_build_prompt_includes_inputs():
    mod = _reload()
    gen = mod.RecipeGenerator()
    prompt = gen._build_prompt(
        ingredients=["chicken", "rice"],
        dietary_restrictions=["gluten-free"],
        cuisine_type="japanese",
        meal_type="dinner",
        difficulty="easy",
    )
    assert "chicken" in prompt and "rice" in prompt
    assert "gluten-free" in prompt
    assert "japanese" in prompt
    assert "dinner" in prompt
    assert "easy" in prompt


def test_parse_recipe_response_extracts_json():
    mod = _reload()
    gen = mod.RecipeGenerator()
    payload = {
        "title": "Test",
        "ingredients": [],
        "instructions": ["step"],
    }
    text = "Here you go!\n" + json.dumps(payload) + "\nEnjoy."
    parsed = gen._parse_recipe_response(text)
    assert parsed["title"] == "Test"
    assert parsed["source"] == "ai_generated"
    assert "id" in parsed and "created_at" in parsed


def test_parse_recipe_response_falls_back_when_invalid():
    mod = _reload()
    gen = mod.RecipeGenerator()
    parsed = gen._parse_recipe_response("no json here at all")
    # Fallback path returns a usable structure rather than raising.
    assert parsed["source"] == "ai_generated"
    assert parsed["title"] == "AI Generated Recipe"
