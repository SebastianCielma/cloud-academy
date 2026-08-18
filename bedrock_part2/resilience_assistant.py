import json
import time
import logging
from pathlib import Path
from typing import Dict, Any, Generator, Optional
import boto3
from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(message)s")

class ResilienceAssistant:
    def __init__(self, primary_model: str, fallback_model: str, region: str = "us-east-1"):
        self.client = boto3.client("bedrock-runtime", region_name=region)
        self.primary_model = primary_model
        self.fallback_model = fallback_model
        self.metrics_log: list[Dict[str, Any]] = []

    def load_prompt(self, filename: str) -> str:
        prompt_path = Path("prompts") / filename
        return prompt_path.read_text(encoding="utf-8")

    def validate_ticket_json(self, response_text: str) -> Dict[str, Any]:
        cleaned_text = response_text.strip()
        if cleaned_text.startswith("```json"):
            cleaned_text = cleaned_text[7:]
        elif cleaned_text.startswith("```"):
            cleaned_text = cleaned_text[3:]
        
        if cleaned_text.endswith("```"):
            cleaned_text = cleaned_text[:-3]
            
        cleaned_text = cleaned_text.strip()

        try:
            data = json.loads(cleaned_text)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON format: {e}. Raw input: {cleaned_text}")

        required_keys = {"category", "priority", "summary", "suggested_response"}
        missing_keys = required_keys - data.keys()
        if missing_keys:
            raise ValueError(f"Missing required fields: {missing_keys}")

        if not isinstance(data["summary"], str) or not isinstance(data["priority"], str):
            raise TypeError("Invalid field types: 'summary' and 'priority' must be strings.")

        return data

    def invoke_with_resilience(self, prompt: str, system_prompt: str) -> str:
        max_attempts = 3
        base_delay = 1.0
        
        for attempt in range(1, max_attempts + 1):
            try:
                return self._invoke(self.primary_model, prompt, system_prompt)
            except ClientError as e:
                error_code = e.response.get("Error", {}).get("Code", "Unknown")
                
                if error_code in ["AccessDeniedException", "ValidationException"]:
                    logging.error(f"Non-retriable error: {error_code}. Aborting.")
                    raise e
                
                if error_code in ["ThrottlingException", "ServiceUnavailableException", "ModelNotReadyException"]:
                    if attempt == max_attempts:
                        logging.warning(f"Exhausted retries on {self.primary_model}. Initiating fallback...")
                        return self._invoke(self.fallback_model, prompt, system_prompt)
                    
                    sleep_time = base_delay * (2 ** (attempt - 1))
                    logging.warning(f"{error_code} detected. Retrying in {sleep_time}s...")
                    time.sleep(sleep_time)
                else:
                    raise e
        return ""

    def _invoke(self, model_id: str, prompt: str, system_prompt: str) -> str:
        start_time = time.perf_counter()
        success = False
        usage = {}
        
        try:
            response = self.client.converse(
                modelId=model_id,
                messages=[{"role": "user", "content": [{"text": prompt}]}],
                system=[{"text": system_prompt}],
                inferenceConfig={"temperature": 0.1}
            )
            reply_text = response["output"]["message"]["content"][0]["text"]
            usage = response["usage"]
            success = True
            return reply_text
        finally:
            latency = int((time.perf_counter() - start_time) * 1000)
            self._record_metrics(model_id, usage.get("inputTokens", 0), usage.get("outputTokens", 0), latency, success)

    def stream_chat(self, prompt: str, system_prompt: str) -> Generator[str, None, None]:
        start_time = time.perf_counter()
        first_token_time = None
        
        response = self.client.converse_stream(
            modelId=self.primary_model,
            messages=[{"role": "user", "content": [{"text": prompt}]}],
            system=[{"text": system_prompt}]
        )
        
        for event in response["stream"]:
            if "contentBlockDelta" in event:
                if not first_token_time:
                    first_token_time = int((time.perf_counter() - start_time) * 1000)
                    logging.info(f"Time to First Token (TTFT): {first_token_time}ms")
                yield event["contentBlockDelta"]["delta"]["text"]

        total_latency = int((time.perf_counter() - start_time) * 1000)
        logging.info(f"Total Stream Latency: {total_latency}ms")

    def _record_metrics(self, model_id: str, tokens_in: int, tokens_out: int, latency: int, success: bool):
        self.metrics_log.append({
            "timestamp": time.time(),
            "model": model_id,
            "input_tokens": tokens_in,
            "output_tokens": tokens_out,
            "latency_ms": latency,
            "success": success
        })