import time
import boto3
from typing import List, Dict, Any, Optional

class BedrockAssistant:
    def __init__(self, model_id: str, region: str = "us-east-1"):
        self.client = boto3.client("bedrock-runtime", region_name=region)
        self.model_id = model_id
        self.history: List[Dict[str, Any]] = []
        self.system_prompt: List[Dict[str, str]] = []

    def set_system_prompt(self, prompt_text: str) -> None:
        self.system_prompt = [{"text": prompt_text}]

    def clear_history(self) -> None:
        self.history = []

    def chat(self, message: str, inference_config: Optional[Dict[str, Any]] = None) -> str:
        if message:
            self.history.append({
                "role": "user",
                "content": [{"text": message}]
            })

        kwargs: Dict[str, Any] = {
            "modelId": self.model_id,
            "messages": self.history,
        }

        if self.system_prompt:
            kwargs["system"] = self.system_prompt
            
        if inference_config:
            kwargs["inferenceConfig"] = inference_config

        start_time = time.perf_counter()
        response = self.client.converse(**kwargs)
        duration_ms = int((time.perf_counter() - start_time) * 1000)

        reply = response["output"]["message"]
        self.history.append(reply)

        self.log_metrics(duration_ms, response["usage"])

        return reply["content"][0]["text"]

    def log_metrics(self, duration: int, usage: Dict[str, int]) -> None:
        print(f"| Model: {self.model_id} | Duration: {duration}ms | "
              f"In: {usage.get('inputTokens')} | Out: {usage.get('outputTokens')} |")