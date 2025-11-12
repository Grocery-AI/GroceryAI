-- Migration: Add soft delete support to room_members table
-- This allows tracking which users have deleted a room from their view
-- Room reappears if that user receives new messages
-- Room is permanently deleted only when all members have soft-deleted it

ALTER TABLE room_members ADD COLUMN deleted_at TIMESTAMP NULL COMMENT 'Soft delete timestamp - NULL means active member';

-- Optional: Add index for better query performance when filtering active members
CREATE INDEX idx_room_members_deleted_at ON room_members(room_id, deleted_at);
