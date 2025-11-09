

from typing import Dict, Set
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[int, Set[WebSocket]] = {}  # room_id -> set of WebSockets

    async def connect(self, websocket: WebSocket, room_id: int):
        await websocket.accept()
        if room_id not in self.active_connections:
            self.active_connections[room_id] = set()
        self.active_connections[room_id].add(websocket)
        total = sum(len(conns) for conns in self.active_connections.values())
        print(f"[WS] connect room {room_id} -> {len(self.active_connections[room_id])} in room, {total} total") 

    def disconnect(self, websocket: WebSocket, room_id: int):
        if room_id in self.active_connections and websocket in self.active_connections[room_id]:
            self.active_connections[room_id].remove(websocket)
            if not self.active_connections[room_id]:
                del self.active_connections[room_id]
            total = sum(len(conns) for conns in self.active_connections.values())
            print(f"[WS] disconnect room {room_id} -> {total} total active")

    async def broadcast(self, message: dict, room_id: int):
        """Broadcast message to all connections in a specific room"""
        if room_id not in self.active_connections:
            return
        
        for connection in list(self.active_connections[room_id]):
            try:
                await connection.send_json(message)
            except Exception:
                try:
                    await connection.close()
                except Exception:
                    pass
                self.disconnect(connection, room_id)
