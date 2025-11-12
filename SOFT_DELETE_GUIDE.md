# 🗑️ 軟刪除房間功能 - 完整實現指南

## 📋 功能說明

實現了房間的軟刪除（Soft Delete）機制：

1. **用戶刪除房間**

   - 房間立即從該用戶的界面消失
   - 即使重新打開應用也不會顯示
   - 數據庫中用戶的 `room_members.deleted_at` 被設置為當前時間

2. **其他用戶發送訊息**

   - 當其他用戶在房間中發送訊息時
   - 該房間自動重新激活（已刪除用戶的 `deleted_at` 設置為 NULL）
   - 房間重新出現在已刪除用戶的列表中

3. **所有用戶都刪除房間**
   - 當房間沒有任何活躍成員時
   - 房間及其所有訊息從資料庫永久刪除

## 🔧 技術實現

### 後端更改

#### 1. 資料庫模型 (`db.py`)

```python
class RoomMember(Base):
    ...
    deleted_at: Mapped["DateTime"] = mapped_column(DateTime(timezone=True), nullable=True)
```

#### 2. API 端點

**新增端點：DELETE /api/rooms/{room_id}**

```python
@app.delete("/api/rooms/{room_id}")
async def delete_room(room_id: int, ...):
    # 標記當前用戶的房間成員為已刪除
    # 如果所有成員都刪除，永久刪除房間
```

**修改端點：GET /api/rooms**

```python
# 現在只返回 deleted_at IS NULL 的房間
```

**修改端點：POST /api/rooms/{room_id}/messages**

```python
# 自動重新激活已刪除的房間（當用戶發送訊息時）
```

### 前端無需更改

- 現有的 `_deleteRoom()` 函數已經正確實現
- API client 的 `deleteRoom()` 方法已經正確調用

## 📊 資料庫遷移步驟

### 本地開發環境

1. **執行遷移 SQL**

   ```bash
   mysql -u chatuser -p groceryshopperai < sql/migration_add_deleted_at.sql
   ```

2. **重啟後端**
   ```bash
   cd backend
   python -m uvicorn app:app --host 0.0.0.0 --port 8000
   ```

### Firebase Cloud Run 部署

1. **執行 SQL 遷移**（在 Cloud SQL 中）

   ```sql
   ALTER TABLE room_members ADD COLUMN deleted_at TIMESTAMP NULL;
   CREATE INDEX idx_room_members_deleted_at ON room_members(room_id, deleted_at);
   ```

2. **部署新代碼**
   ```bash
   gcloud run deploy grocery-shopper-api \
     --source ./backend \
     --region us-west1 \
     --allow-unauthenticated
   ```

## 🧪 測試步驟

1. **準備測試環境**

   - 創建兩個用戶：User A 和 User B
   - 創建一個聊天室，兩個用戶都是成員

2. **測試刪除功能**

   - User A 點擊刪除按鈕
   - ✅ 房間立即消失
   - ✅ User A 重新打開應用，房間仍然消失
   - ✅ User B 的應用中房間仍然存在

3. **測試重新激活**

   - User B 在房間中發送訊息
   - ✅ User A 的應用刷新後，房間重新出現

4. **測試永久刪除**
   - User B 也刪除房間
   - ✅ 房間和所有訊息從資料庫永久刪除

## 📝 API 文檔

### DELETE /api/rooms/{room_id}

刪除（軟刪除）當前用戶的聊天室

**參數：**

- `room_id` (path): 房間 ID

**認證：** Bearer Token

**響應（成功）：**

```json
{
  "ok": true,
  "message": "Room deleted for you"
}
```

**響應（錯誤）：**

- `404 Room not found` - 房間不存在
- `404 User is not a member of this room` - 用戶不是房間成員
- `401 Invalid user` - 認證失敗

## 🔍 驗證遷移成功

### 檢查新列是否存在

```sql
DESCRIBE room_members;
-- 應該看到 deleted_at 列
```

### 檢查索引是否創建

```sql
SHOW INDEX FROM room_members;
-- 應該看到 idx_room_members_deleted_at 索引
```

## ⚠️ 常見問題

### Q: 如何回滾遷移？

```sql
-- 刪除遷移記錄和列
DROP INDEX idx_room_members_deleted_at ON room_members;
ALTER TABLE room_members DROP COLUMN deleted_at;
```

### Q: 已刪除的房間是否可以恢復？

- 軟刪除（單個用戶）：可以，其他用戶發送訊息時自動恢復
- 硬刪除（所有用戶）：不可以，數據已永久刪除

### Q: 如何查看哪些房間被刪除？

```sql
SELECT r.name, rm.user_id, rm.deleted_at
FROM room_members rm
JOIN rooms r ON rm.room_id = r.id
WHERE rm.deleted_at IS NOT NULL;
```

## 🚀 後續優化

- [ ] 添加軟刪除房間的恢復功能（管理員）
- [ ] 添加刪除操作的審計日誌
- [ ] 實現定期清理永久刪除房間的垃圾回收
- [ ] 添加用戶設置以禁用房間自動重新激活

## 📞 支持

如果部署過程中遇到問題：

1. 檢查後端日誌

   ```bash
   gcloud run logs read grocery-shopper-api --follow
   ```

2. 驗證資料庫連接

   ```bash
   mysql -h <host> -u chatuser -p -e "SELECT COUNT(*) FROM room_members;"
   ```

3. 測試 API 端點
   ```bash
   curl -X DELETE https://your-api.com/api/rooms/1 \
     -H "Authorization: Bearer <token>"
   ```
