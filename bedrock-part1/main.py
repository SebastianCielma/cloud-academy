from bedrock_assistant import BedrockAssistant

MODEL_CLAUDE = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
MODEL_NOVA = "us.amazon.nova-lite-v1:0"

def run_experiments() -> None:
    assistant = BedrockAssistant(MODEL_CLAUDE)

    print("\n--- TEST 1: No System Prompt vs System Prompt ---")
    msg1 = "My payment was charged twice. What should I do?"
    
    assistant.chat(msg1)
    assistant.clear_history()

    assistant.set_system_prompt(
        "You are a technical support assistant. Your task is to help users understand "
        "their problem and suggest appropriate next steps. Do not invent company policies."
    )
    assistant.chat(msg1)

    print("\n--- TEST 2: Multi-turn Conversation ---")
    assistant.clear_history()
    assistant.chat("My payment failed.")
    assistant.chat("Can I try again?")

    print("\n--- TEST 3: Inference Parameters ---")
    assistant.clear_history()
    msg2 = "Write a short creative story about a failed server."
    
    assistant.chat(msg2, {"temperature": 0.1, "maxTokens": 100})
    assistant.clear_history()
    assistant.chat(msg2, {"temperature": 0.9, "maxTokens": 100})
    assistant.clear_history()
    assistant.chat(msg2, {"topP": 0.5, "maxTokens": 100})

    print("\n--- TEST 4: Model Comparison ---")
    assistant.clear_history()
    nova_assistant = BedrockAssistant(MODEL_NOVA)
    nova_assistant.set_system_prompt("You are a technical support assistant.")
    
    prompt = "Explain DNS in one sentence."
    assistant.chat(prompt)
    nova_assistant.chat(prompt)

if __name__ == "__main__":
    run_experiments()