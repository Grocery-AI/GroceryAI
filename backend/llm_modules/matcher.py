import json
from typing import List, Dict, Any

from llm import chat_completion
from llm_modules.llm_utils import (
    format_chat_history,
    extract_json,
    extract_goal,
    extract_assigned_members,
    get_available_members,
)


async def suggest_invites(
    members: List[str],
    chat_history: List[Dict[str, str]],
    goal: str | None = None,
    model_name: str = "openai"
) -> Dict[str, Any]:

    if not goal:
        goal = await extract_goal(chat_history, model_name=model_name)

    assigned = await extract_assigned_members(chat_history, members, model_name=model_name)
    available = get_available_members(members, assigned)

    system_prompt = """
    You are an AI assistant helping a group plan an event.

    STRICT RULES:
    - Output ONLY VALID JSON.
    - No commentary outside JSON.

    JSON FORMAT:
    {
        "suggested_invites": ["<member name>"],
        "missing_roles": ["<string>"],
        "narrative": "<string>"
    }

    ADDITIONAL RULES:
    - Use ONLY names from the provided member list.
    - "suggested_invites" MUST be chosen from the available member list.
    - If additional help is needed beyond available members, place type descriptions into "missing_roles".
    - "narrative" should be friendly and casual.
    """

    chat_text = format_chat_history(chat_history)

    user_prompt = f"""
    Goal: {goal}

    All members: {', '.join(members)}
    Assigned members: {', '.join(assigned) if assigned else 'None'}
    Available members: {', '.join(available) if available else 'None'}

    Chat history:
    {chat_text}

    Generate the JSON suggestion now.
    """

    raw = await chat_completion(
        [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        model_name=model_name,
    )

    data = extract_json(raw)

    suggested_invites = [
        m for m in data.get("suggested_invites", []) if m in available
    ]

    missing_roles = data.get("missing_roles", [])

    narrative = data.get("narrative", "Here are some suggestions to help your group planning.")

    return {
        "suggested_invites": suggested_invites,
        "missing_roles": missing_roles,
        "narrative": narrative,
    }
