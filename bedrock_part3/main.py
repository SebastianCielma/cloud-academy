import sys
from rag_assistant import RagAssistant

MODEL_ID = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
KNOWLEDGE_BASE_ID = "CIGUQSVFHM"  

def run_part3_experiments():
    if KNOWLEDGE_BASE_ID == "WPISZ_SWOJE_KB_ID":
        print("Please update KNOWLEDGE_BASE_ID in the code first.")
        sys.exit(1)

    rag = RagAssistant(MODEL_ID, KNOWLEDGE_BASE_ID)

    print("\n--- 1. RETRIEVE ONLY (No Generation) ---")
    query_1 = "How long can Premium customers return a product?"
    chunks = rag.retrieve_only(query_1, max_results=3)
    for idx, chunk in enumerate(chunks):
        print(f"\nResult {idx+1}:")
        print(f"Source: {chunk['source_uri']}")
        print(f"Score: {chunk['score']}")
        print(f"Text: {chunk['chunk_text'][:100]}...")

    print("\n--- 2. RETRIEVE AND GENERATE ---")
    result = rag.retrieve_and_generate(query_1)
    print(result)

    print("\n--- 3. UNKNOWN INFORMATION RESTRICTION ---")
    query_2 = "Does the company offer lifetime warranty for products purchased in Japan?"
    result_unknown = rag.retrieve_and_generate(query_2)
    print(result_unknown)

    print("\n--- 4. NUMBER OF RETRIEVED RESULTS EXPERIMENT ---")
    print("Testing with 2 results:")
    print(rag.retrieve_and_generate(query_1, max_results=2))
    print("\nTesting with 10 results:")
    print(rag.retrieve_and_generate(query_1, max_results=10))

if __name__ == "__main__":
    run_part3_experiments()