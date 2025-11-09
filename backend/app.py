import os
import asyncio
from typing import Optional, List
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, status, Request
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from dotenv import load_dotenv

from db import SessionLocal, init_db, User, Message, Room, RoomMember
from auth import get_password_hash, verify_password, create_access_token, get_current_user_token
from websocket_manager import ConnectionManager
from llm import chat_completion

load_dotenv()

APP_HOST = os.getenv("APP_HOST", "0.0.0.0")
APP_PORT = int(os.getenv("APP_PORT", "8000"))
GROCERY_CSV_PATH = os.getenv("GROCERY_CSV_PATH", "./GroceryDataset.csv")
CSV_HEADERS = ["Sub Category", " Price ", "Rating", "Title"]

app = FastAPI(title="Group Chat with LLM Bot")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

manager = ConnectionManager()

# --------- Schemas ---------
class AuthPayload(BaseModel):
    username: str
    password: str

class MessagePayload(BaseModel):
    content: str

class RoomPayload(BaseModel):
    name: str

class InvitePayload(BaseModel):
    username: str

# --------- Dependencies ---------
async def get_db() -> AsyncSession:
    async with SessionLocal() as session:
        yield session

# --------- Utilities ---------
async def broadcast_message(session: AsyncSession, msg: Message, room_id: int):
    """Broadcast a message to all WebSocket clients connected to a room"""
    username = None
    if msg.user_id:
        u = await session.get(User, msg.user_id)
        username = u.username if u else "unknown"
    await manager.broadcast({
        "type": "message",
        "room_id": room_id,
        "message": {
            "id": msg.id,
            "username": username if not msg.is_bot else "LLM Bot",
            "content": msg.content,
            "is_bot": msg.is_bot,
            "created_at": str(msg.created_at)
        }
    }, room_id)

async def maybe_answer_with_llm(content: str, room_id: int):
    """Generate an LLM response if message mentions @gro"""
    if "@gro" not in content:
        return
    # Remove @gro tag from content before sending to LLM
    llm_content = content.replace("@gro", "").strip()
    system_prompt = (
        "You are a helpful assistant participating in a small group chat. "
        "Provide concise, accurate answers suitable for a shared chat context. "
        "Cite facts succinctly when helpful and avoid extremely long messages."
    )
    try:
        reply_text = await chat_completion([
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": llm_content}
        ])
    except Exception as e:
        reply_text = f"(LLM error) {e}"
    
    # Create new session for this async task
    async with SessionLocal() as session:
        bot_msg = Message(room_id=room_id, user_id=None, content=reply_text, is_bot=True)
        session.add(bot_msg)
        await session.commit()
        await session.refresh(bot_msg)
        await broadcast_message(session, bot_msg, room_id)

# --------- Routes ---------
@app.on_event("startup")
async def on_startup():
    await init_db()

@app.post("/api/signup")
async def signup(payload: AuthPayload, session: AsyncSession = Depends(get_db)):
    """Create a new user"""
    existing = await session.execute(select(User).where(User.username == payload.username))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Username already taken")
    
    u = User(username=payload.username, password_hash=get_password_hash(payload.password))
    session.add(u)
    await session.commit()
    await session.refresh(u)
    
    token = create_access_token({"sub": u.username})
    return {"ok": True, "token": token}

@app.post("/api/login")
async def login(payload: AuthPayload, session: AsyncSession = Depends(get_db)):
    """Login and return authentication token"""
    res = await session.execute(select(User).where(User.username == payload.username))
    u = res.scalar_one_or_none()
    if not u or not verify_password(payload.password, u.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_access_token({"sub": u.username})
    return {"ok": True, "token": token}

@app.get("/api/rooms")
async def get_rooms(username: str = Depends(get_current_user_token), session: AsyncSession = Depends(get_db)):
    """Get all rooms that the user is a member of"""
    res = await session.execute(select(User).where(User.username == username))
    u = res.scalar_one_or_none()
    if not u:
        raise HTTPException(status_code=401, detail="Invalid user")
    
    # Get all rooms this user is a member of
    member_res = await session.execute(
        select(Room).join(RoomMember).where(RoomMember.user_id == u.id)
    )
    rooms = member_res.scalars().all()
    return {
        "rooms": [{"id": r.id, "name": r.name, "created_at": str(r.created_at)} for r in rooms]
    }

@app.post("/api/rooms")
async def create_room(payload: RoomPayload, username: str = Depends(get_current_user_token), session: AsyncSession = Depends(get_db)):
    """Create a new room"""
    res = await session.execute(select(User).where(User.username == username))
    u = res.scalar_one_or_none()
    if not u:
        raise HTTPException(status_code=401, detail="Invalid user")
    
    # Check if room name already exists
    existing = await session.execute(select(Room).where(Room.name == payload.name))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Room name already taken")
    
    # Create room
    room = Room(name=payload.name, owner_id=u.id)
    session.add(room)
    await session.commit()
    await session.refresh(room)
    
    # Add creator to room
    member = RoomMember(room_id=room.id, user_id=u.id)
    session.add(member)
    await session.commit()
    
    return {"ok": True, "room": {"id": room.id, "name": room.name}}

@app.get("/api/rooms/{room_id}/members")
async def get_room_members(room_id: int, session: AsyncSession = Depends(get_db)):
    """Get members of a room"""
    room = await session.get(Room, room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    members_res = await session.execute(
        select(User).join(RoomMember).where(RoomMember.room_id == room_id)
    )
    members = members_res.scalars().all()
    return {
        "members": [{"id": m.id, "username": m.username} for m in members]
    }

@app.post("/api/rooms/{room_id}/invite")
async def invite_to_room(room_id: int, payload: InvitePayload, username: str = Depends(get_current_user_token), session: AsyncSession = Depends(get_db)):
    """Invite a user to a room"""
    # Check if invoker is room owner
    room = await session.get(Room, room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    res = await session.execute(select(User).where(User.username == username))
    u = res.scalar_one_or_none()
    if not u or room.owner_id != u.id:
        raise HTTPException(status_code=403, detail="Only room owner can invite")
    
    # Get user to invite
    invite_res = await session.execute(select(User).where(User.username == payload.username))
    invite_user = invite_res.scalar_one_or_none()
    if not invite_user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check if already member
    member_check = await session.execute(
        select(RoomMember).where(
            (RoomMember.room_id == room_id) & 
            (RoomMember.user_id == invite_user.id)
        )
    )
    if member_check.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="User already in room")
    
    # Add user to room
    member = RoomMember(room_id=room_id, user_id=invite_user.id)
    session.add(member)
    await session.commit()
    
    return {"ok": True, "message": f"User {payload.username} added to room"}

@app.get("/api/rooms/{room_id}/messages")
async def get_room_messages(room_id: int, limit: int = 50, session: AsyncSession = Depends(get_db)):
    """Get messages from a specific room"""
    room = await session.get(Room, room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    res = await session.execute(
        select(Message)
        .where(Message.room_id == room_id)
        .order_by(desc(Message.created_at))
        .limit(limit)
    )
    items = list(reversed(res.scalars().all()))
    out = []
    for m in items:
        username = None
        if not m.is_bot and m.user_id:
            u = await session.get(User, m.user_id)
            username = u.username if u else "unknown"
        out.append({
            "id": m.id,
            "username": "LLM Bot" if m.is_bot else (username or "unknown"),
            "content": m.content,
            "is_bot": m.is_bot,
            "created_at": str(m.created_at)
        })
    return {"messages": out}

@app.post("/api/rooms/{room_id}/messages")
async def post_room_message(room_id: int, payload: MessagePayload, username: str = Depends(get_current_user_token), session: AsyncSession = Depends(get_db)):
    """Post a message to a specific room"""
    try:
        # Check if room exists
        room = await session.get(Room, room_id)
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        
        # Get user
        res = await session.execute(select(User).where(User.username == username))
        u = res.scalar_one_or_none()
        if not u:
            raise HTTPException(status_code=401, detail="Invalid user")
        
        # Check if user is member of room
        member_check = await session.execute(
            select(RoomMember).where(
                (RoomMember.room_id == room_id) & 
                (RoomMember.user_id == u.id)
            )
        )
        if not member_check.scalar_one_or_none():
            raise HTTPException(status_code=403, detail="Not a member of this room")
        
        # Create message
        m = Message(room_id=room_id, user_id=u.id, content=payload.content, is_bot=False)
        session.add(m)
        await session.commit()
        await session.refresh(m)
        
        await broadcast_message(session, m, room_id)
        asyncio.create_task(maybe_answer_with_llm(payload.content, room_id))
        
        return {"ok": True, "id": m.id}
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in post_room_message: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint that groups connections by room_id"""
    # Extract room_id from query parameters
    room_id_str = websocket.query_params.get("room_id")
    if not room_id_str:
        await websocket.close(code=1008, reason="room_id required")
        return
    
    try:
        room_id = int(room_id_str)
    except ValueError:
        await websocket.close(code=1008, reason="room_id must be integer")
        return
    
    try:
        await manager.connect(websocket, room_id)
        try:
            while True:
                await websocket.receive_text()
        except Exception as e:
            print(f"WebSocket error: {e}")
    finally:
        manager.disconnect(websocket, room_id)

# Serve frontend
app.mount("/", StaticFiles(directory="../frontend", html=True), name="static")
from pathlib import Path

FRONTEND_DIR = Path(__file__).parent.parent / "frontend"

app.mount(
    "/.well-known",
    StaticFiles(directory=str(FRONTEND_DIR / ".well-known"), html=False),
    name="wellknown",
)
