import json
import sys
import logging
from typing import Dict, Any
from pydantic import ValidationError
from src.models.resources import EnvironmentState

logger = logging.getLogger(__name__)

def load_json_raw(filepath: str) -> Dict[str, Any]:
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        logger.error(f"File not found: {filepath}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON format in {filepath}: {e}")
        sys.exit(1)

def parse_environment_state(filepath: str) -> EnvironmentState:
    raw_data = load_json_raw(filepath)
    try:
        return EnvironmentState(**raw_data)
    except ValidationError as e:
        logger.error(f"Schema validation failed for {filepath}:\n{e}")
        sys.exit(1)