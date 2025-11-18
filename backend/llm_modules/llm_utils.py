import json
import re
from typing import List, Dict, Any

from llm import chat_completion

def format_chat_history(chat_history: List[Dict[str, str]]) -> str:
    lines = []
    for m in chat_history:
        role = "User" if m["role"] == "user" else "Assistant"
        content = m["content"].replace("\n", " ")
        lines.append(f"[{role}] {content}")
    return "\n".join(lines)

def extract_json(text: str) -> Dict[str, Any]:
    """
    Production-grade LLM JSON extractor.
    Handles:
    - ```json fenced blocks
    - raw JSON inside text
    - extra commentary before/after JSON
    - nested braces
    - Gemini/Claude/OpenAI mixed output
    
    Returns empty dict if parsing fails.
    """

    if not text or not isinstance(text, str):
        return {}

    # 1) Try direct parse
    try:
        return json.loads(text)
    except Exception:
        pass

    # 2) Try to extract fenced code block ```json ... ```
    fenced = re.findall(r"```(?:json)?(.*?)```", text, re.DOTALL | re.IGNORECASE)
    for block in fenced:
        block = block.strip()
        try:
            return json.loads(block)
        except Exception:
            continue

    # 3) Find the first { and last } and try to parse the substring
    start = text.find("{")
    end = text.rfind("}")
    if 0 <= start < end:
        snippet = text[start : end + 1]
        try:
            return json.loads(snippet)
        except Exception:
            pass

    # 4) Try to recover partial JSON using regex (matches balanced {...})
    json_candidates = re.findall(r"\{(?:[^{}]|(?:\{.*\}))*\}", text, re.DOTALL)
    for candidate in json_candidates:
        try:
            return json.loads(candidate)
        except Exception:
            continue

    # 5) Last-ditch: fix common errors like trailing commas
    try:
        cleaned = re.sub(r",\s*}", "}", text)
        cleaned = re.sub(r",\s*]", "]", cleaned)
        start = cleaned.find("{")
        end = cleaned.rfind("}") + 1
        if start != -1 and end != -1:
            return json.loads(cleaned[start:end])
    except Exception:
        pass

    return {}

def ensure_narrative(data: Dict[str, Any], default: str) -> Dict[str, Any]:
    """
    Guarantee that `data` contains a non-empty 'narrative' string.
    If missing or empty, fill with default.
    """
    if not isinstance(data, dict):
        data = {}
    narrative = data.get("narrative", "")
    if not isinstance(narrative, str) or not narrative.strip():
        data["narrative"] = default
    return data

async def extract_goal(chat_history: List[Dict[str, str]], model_name: str = "openai",) -> str:
    """
    Extract the event goal from chat history using LLM.
    If none found, returns "".
    """
    chat_text = format_chat_history(chat_history)
    
    system_prompt = """
    You are an AI assistant. Identify the main event goal of the group based on the chat history.
    
    The goal could be things like:
    - "BBQ party this Saturday"
    - "Friendsgiving dinner"
    - "Weekly grocery shopping"
    - "Hotpot night with friends"
    - "Prepare next week's menu and restock"
    
    Output JSON ONLY:
    {
        "goal": "<string>"
    }
    
    If there is no clear goal, return:
    {
        "goal": ""
    }
    """
    
    user_prompt = f"Chat history:\n{chat_text}\n\nExtract the goal in JSON."
    
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]
    
    raw = await chat_completion(messages, model_name=model_name)
    data = extract_json(raw)
    return data.get("goal", "")

async def extract_assigned_members(chat_history: List[Dict[str, str]], members: List[str], model_name: str = "openai",) -> List[str]:
    """
    Let LLM decide which members from the list have been assigned tasks based on the chat history.
    Only names present in `members` will be kept.
    """
    chat_text = format_chat_history(chat_history)
    
    system_prompt = """
    You detect which members from the given list have been assigned tasks based on the chat history.
    
    Output JSON ONLY:
    {
        "assigned": ["name1", "name2"]
    }
    
    Rules:
    - Only include names that appear in the provided member list.
    - If nobody is clearly assigned, return an empty list.
    """
    
    user_prompt = f"""
    Chat history:
    {chat_text}
    
    Member list: {", ".join(members)}
    """
    
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]
    
    raw = await chat_completion(messages, model_name=model_name)
    data = extract_json(raw)
    
    assigned = data.get("assigned", [])
    # Make sure returning the name in members
    return [m for m in assigned if m in members]

def get_available_members(members: List[str], assigned: List[str]) -> List[str]:
    # Return members who are not yet assigned.
    return [m for m in members if m not in assigned]