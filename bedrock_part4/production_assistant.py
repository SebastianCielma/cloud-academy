import time
import uuid
import logging
import boto3
import botocore

class ProductionSystem:
    def __init__(self, model_id, prompt, kb_id, guardrail_id, guardrail_version, region="us-east-1"):
        self.bedrock_runtime = boto3.client("bedrock-runtime", region_name=region)
        self.bedrock_agent = boto3.client("bedrock-agent-runtime", region_name=region)
        self.model_id = model_id
        self.prompt = prompt
        self.kb_id = kb_id
        self.guardrail_id = guardrail_id
        self.guardrail_version = guardrail_version
        
    def retrieve_context(self, query: str):
        try:
            res = self.bedrock_agent.retrieve(
                knowledgeBaseId=self.kb_id,
                retrievalQuery={'text': query},
                retrievalConfiguration={'vectorSearchConfiguration': {'numberOfResults': 3}}
            )
        except botocore.exceptions.ClientError as e:
            if "managedSearchConfiguration" in str(e):
                res = self.bedrock_agent.retrieve(
                    knowledgeBaseId=self.kb_id, 
                    retrievalQuery={'text': query}
                )
            else:
                return "", []
                
        results = res.get("retrievalResults", [])
        context_text = "\n".join([item["content"]["text"] for item in results])
        # Wyciągamy URI każdego chunka, aby móc wyliczyć "source correctness"
        sources = [item.get("location", {}).get("s3Location", {}).get("uri", "") for item in results]
        return context_text, sources

    def invoke(self, query: str) -> dict:
        req_id = str(uuid.uuid4())
        ts = time.time()
        context, sources = self.retrieve_context(query)
        user_prompt = f"Context:\n{context}\n\nQuestion: {query}"
        
        start_t = time.perf_counter()
        try:
            response = self.bedrock_runtime.converse(
                modelId=self.model_id,
                messages=[{"role": "user", "content": [{"text": user_prompt}]}],
                system=[{"text": self.prompt}],
                inferenceConfig={"temperature": 0.0},
                guardrailConfig={ 
                    "guardrailIdentifier": self.guardrail_id, 
                    "guardrailVersion": self.guardrail_version, 
                    "trace": "enabled"
                }
            )
            latency = int((time.perf_counter() - start_t) * 1000)
            
            if response.get("stopReason") == "guardrail_intervened":
                logging.warning(f"Guardrail Blocked | ReqID: {req_id} | TS: {ts} | Reason: guardrail_intervened")
                return {
                    "status": "blocked", 
                    "message": "This request cannot be processed.", 
                    "latency": latency, 
                    "tokens_in": 0, 
                    "tokens_out": 0,
                    "sources": sources
                }
            
            usage = response.get("usage", {})
            return {
                "status": "success",
                "message": response["output"]["message"]["content"][0]["text"],
                "latency": latency,
                "tokens_in": usage.get("inputTokens", 0),
                "tokens_out": usage.get("outputTokens", 0),
                "sources": sources
            }
        except botocore.exceptions.ClientError as e:
            logging.error(f"API Error | ReqID: {req_id} | Error: {e}")
            return {"status": "error", "message": "Internal error.", "latency": 0, "tokens_in": 0, "tokens_out": 0, "sources": []}

class Evaluator:
    def __init__(self, judge_model_id, region="us-east-1"):
        self.client = boto3.client("bedrock-runtime", region_name=region)
        self.judge_model_id = judge_model_id

    def judge_answer(self, question: str, expected: str, actual: str) -> int:
        if actual == "This request cannot be processed.":
            return 1 if "Block" in expected else 0
        if "Block" in expected:
            return 0
            
        judge_prompt = f"Question: {question}\nExpected Intent: {expected}\nActual Answer: {actual}\nScore 1 if the actual answer aligns with the expected intent. Otherwise score 0. Output ONLY the number 1 or 0."
        
        res = self.client.converse(
            modelId=self.judge_model_id,
            messages=[{"role": "user", "content": [{"text": judge_prompt}]}],
            inferenceConfig={"temperature": 0.0, "maxTokens": 10}
        )
        return 1 if "1" in res["output"]["message"]["content"][0]["text"] else 0