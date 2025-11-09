import asyncio
import sys
sys.path.append('/Users/ychia/GroceryShopperAI/backend')

from db import SessionLocal, User, Room, RoomMember
from sqlalchemy import select

async def test():
    async with SessionLocal() as session:
        # Get first user
        res = await session.execute(select(User).limit(1))
        user = res.scalar_one()
        print(f"User: {user.username}")
        
        # Check rooms before
        res = await session.execute(
            select(Room).join(RoomMember).where(RoomMember.user_id == user.id)
        )
        rooms_before = res.scalars().all()
        print(f"Rooms before: {len(rooms_before)} - {[r.name for r in rooms_before]}")
        
        # Create new room
        new_room = Room(name=f"Test Room {len(rooms_before)}", owner_id=user.id)
        session.add(new_room)
        await session.commit()
        await session.refresh(new_room)
        print(f"Created room: {new_room.name} (ID: {new_room.id})")
        
        # Add user as member
        member = RoomMember(room_id=new_room.id, user_id=user.id)
        session.add(member)
        await session.commit()
        print(f"Added user as member")
        
        # Check rooms after
        res = await session.execute(
            select(Room).join(RoomMember).where(RoomMember.user_id == user.id)
        )
        rooms_after = res.scalars().all()
        print(f"Rooms after: {len(rooms_after)} - {[r.name for r in rooms_after]}")

asyncio.run(test())
