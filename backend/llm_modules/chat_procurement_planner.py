import json
from typing import List, Dict, Any

from llm_modules.llm_utils import (extract_goal, extract_json, format_chat_history,)
from llm import chat_completion

async def generate_procurement_plan(chat_history: List[Dict[str, str]], model_name: str = "openai",) -> Dict[str, Any]:
    """
    Chat-based procurement planner
    Generate a procurement (shopping) plan based purely on chat history.
    """
    
    inferred_goal = await extract_goal(chat_history, model_name=model_name)
    chat_text = format_chat_history(chat_history)
    
    system_prompt = """
    You are an AI Procurement Planner.

    Convert the chat history and goal into a structured JSON procurement plan.

    RULES:
    - Output ONLY VALID JSON. 
    - DO NOT add commentary outside JSON.
    - Use EXACT FIELD NAMES below.

    JSON FORMAT:
    {
        "goal": "<string>",
        "summary": "<string>",
        "narrative": "<string>",
        "items": [
            {
                "name": "<string>",
                "quantity": "<string or number>",
                "notes": "<string>"
            }
        ]
    }
    """

    
    user_content = json.dumps(
        {
            "inferred_goal": inferred_goal,
            "chat_history_text": chat_text,
        },
        indent=2
    )
    
    raw = await chat_completion(
        [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content},
        ],
        model_name=model_name,
    )

    data = extract_json(raw)
    
    return {
        "goal": data.get("goal", inferred_goal),
        "summary": data.get("summary", "Here is your shopping summary."),
        "narrative": data.get("narrative", "Here is your procurement plan."),
        "items": data.get("items", []),
    }