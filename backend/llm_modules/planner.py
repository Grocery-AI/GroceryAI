import json
from typing import List, Dict, Any

from llm import chat_completion
from llm_modules.llm_utils import (
    format_chat_history,
    extract_json,
    extract_goal,
)


async def generate_group_plan(
    chat_history: List[Dict[str, str]],
    goal: str | None = None,
    members: List[str] | None = None,
    model_name: str = "openai"
) -> Dict[str, Any]:
    """
    Generate a structured group plan based on chat context.
    """

    if not goal:
        goal = await extract_goal(chat_history, model_name=model_name)

    members = members or []

    system_prompt = """
    You are an AI assistant generating a structured group plan.

    STRICT RULES:
    - Output **ONLY VALID JSON**.
    - No explanations outside the JSON.
    - Use these EXACT field names:

    {
        "event": "<string>",
        "summary": "<string>",
        "items": [
            {
                "name": "<string>",
                "assigned_to": "<string>"
            }
        ],
        "timeline": ["<string>", "<string>"],
        "narrative": "<string>"
    }

    ADDITIONAL RULES:
    - If assigned_to is not in the provided member list, use "Unassigned".
    - "timeline" MUST be an array.
    - "items" MUST be an array.
    - Make narrative friendly.
    - Use ONLY member names provided (no new people).
    """

    chat_text = format_chat_history(chat_history)
    members_list = ", ".join(members) if members else "None"

    user_prompt = f"""
    Goal: {goal}
    Members: {members_list}

    Chat history:
    {chat_text}

    Generate JSON with all required keys.
    """

    raw = await chat_completion(
        [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        model_name=model_name,
    )

    data = extract_json(raw)

    # Fallback + normalization
    event = data.get("event", goal or "")
    summary = data.get("summary", "Here is your group plan.")
    items = data.get("items", [])
    timeline = data.get("timeline", [])
    narrative = data.get("narrative", "Here is your plan!")

    # Normalize timeline
    if not isinstance(timeline, list):
        timeline = [str(timeline)]

    # Normalize assigned_to
    fixed_items = []
    for item in items:
        assigned = item.get("assigned_to", "Unassigned")
        if assigned not in members:
            assigned = "Unassigned"
        fixed_items.append(
            {
                "name": item.get("name", ""),
                "assigned_to": assigned
            }
        )

    return {
        "event": event,
        "summary": summary,
        "items": fixed_items,
        "timeline": timeline,
        "narrative": narrative
    }
