import json
import boto3
import botocore
from typing import Dict, Any, List

class RagAssistant:
    def __init__(self, model_id: str, kb_id: str, region: str = "us-east-1"):
        self.bedrock_runtime = boto3.client("bedrock-runtime", region_name=region)
        self.bedrock_agent = boto3.client("bedrock-agent-runtime", region_name=region)
        self.model_id = model_id
        self.kb_id = kb_id

    def retrieve_only(self, query: str, max_results: int = 5) -> List[Dict[str, Any]]:
        try:
            response = self.bedrock_agent.retrieve(
                knowledgeBaseId=self.kb_id,
                retrievalQuery={'text': query},
                retrievalConfiguration={
                    'vectorSearchConfiguration': {'numberOfResults': max_results}
                }
            )
        except botocore.exceptions.ClientError as e:
            error_msg = e.response.get("Error", {}).get("Message", "")
            if "managedSearchConfiguration" in error_msg:
                response = self.bedrock_agent.retrieve(
                    knowledgeBaseId=self.kb_id,
                    retrievalQuery={'text': query}
                )
            else:
                raise e
        
        results = []
        for res in response.get("retrievalResults", []):
            location = res.get("location", {})
            s3_uri = location.get("s3Location", {}).get("uri", "unknown")
            
            results.append({
                "chunk_text": res.get("content", {}).get("text", ""),
                "source_uri": s3_uri,
                "score": res.get("score", 0.0)
            })
        return results

    def retrieve_and_generate(self, query: str, max_results: int = 5) -> Dict[str, Any]:
        retrieved_data = self.retrieve_only(query, max_results)
        
        context = ""
        sources = set()
        for idx, item in enumerate(retrieved_data):
            context += f"--- Document {idx+1} ---\n{item['chunk_text']}\n"
            if item['source_uri'] != "unknown":
                sources.add(item['source_uri'].split("/")[-1])
            
        system_prompt = (
            "You are a customer support agent. Answer the user's question based ONLY on the provided context. "
            "If the answer is not in the context, state that you do not have this information. "
            "Output MUST be strict JSON matching this schema: "
            "{\"answer\": \"your answer\", \"sources\": [\"source1.txt\", \"source2.txt\"]}"
        )
        
        user_prompt = f"Context:\n{context}\n\nQuestion: {query}"
        
        response = self.bedrock_runtime.converse(
            modelId=self.model_id,
            messages=[{"role": "user", "content": [{"text": user_prompt}]}],
            system=[{"text": system_prompt}],
            inferenceConfig={"temperature": 0.0}
        )
        
        raw_text = response["output"]["message"]["content"][0]["text"].strip()
        if raw_text.startswith("```json"):
            raw_text = raw_text[7:-3].strip()
        
        try:
            return json.loads(raw_text)
        except json.JSONDecodeError:
            return {"answer": raw_text, "sources": list(sources)}