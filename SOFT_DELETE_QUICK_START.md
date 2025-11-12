# 🚀 快速部署清單 - 軟刪除房間功能

## ✅ 已完成的代碼更改

- [x] 後端 API 端點

  - ✅ `DELETE /api/rooms/{room_id}` - 刪除房間
  - ✅ `GET /api/rooms` - 修改為只返回未刪除房間
  - ✅ `POST /api/rooms/{room_id}/messages` - 修改為自動重新激活房間

- [x] 資料庫模型

  - ✅ `RoomMember` 添加 `deleted_at` 列

- [x] 前端
  - ✅ 無需修改（已經正確實現）

## 📦 需要執行的步驟

### 步驟 1: 更新資料庫（選一種方式）

**方式 A：本地開發環境**

```bash
cd ~/GroceryShopperAI
mysql -u chatuser -p groceryshopperai < sql/migration_add_deleted_at.sql
```

**方式 B：Firebase Cloud SQL**

1. 進入 Google Cloud Console
2. 選擇 Cloud SQL 實例
3. 打開「SQL 工作流程」
4. 執行：
   ```sql
   ALTER TABLE room_members ADD COLUMN deleted_at TIMESTAMP NULL COMMENT 'Soft delete timestamp - NULL means active member';
   CREATE INDEX idx_room_members_deleted_at ON room_members(room_id, deleted_at);
   ```

### 步驟 2: 部署後端

**本地開發**

```bash
cd backend
python -m uvicorn app:app --host 0.0.0.0 --port 8000
```

**Firebase Cloud Run**

```bash
gcloud run deploy grocery-shopper-api \
  --source ./backend \
  --region us-west1 \
  --allow-unauthenticated
```

### 步驟 3: 重新啟動 Flutter 應用

```bash
cd flutter_frontend
flutter run -d <device_id>
```

## 🧪 驗證功能

### 快速測試

1. 用 User A 刪除房間 → 房間消失 ✓
2. 重啟應用 → 房間仍然消失 ✓
3. User B 發送訊息 → User A 房間重新出現 ✓
4. 兩個用戶都刪除 → 房間永久刪除 ✓

### 檢查資料庫

```bash
# 列出已刪除的房間
mysql -u chatuser -p groceryshopperai -e "
SELECT r.name, u.username, rm.deleted_at
FROM room_members rm
JOIN rooms r ON rm.room_id = r.id
JOIN users u ON rm.user_id = u.id
WHERE rm.deleted_at IS NOT NULL;"
```

## 📊 功能摘要

| 場景         | 行為         | 資料庫               |
| ------------ | ------------ | -------------------- |
| 用戶刪除房間 | 立即消失     | `deleted_at = NOW()` |
| 重啟應用     | 房間仍消失   | 查詢過濾已刪除       |
| 其他用戶發訊 | 房間重新出現 | `deleted_at = NULL`  |
| 所有人都刪   | 永久刪除     | 房間及訊息刪除       |

## 🔗 相關文檔

- 詳細指南：`SOFT_DELETE_GUIDE.md`
- SQL 遷移：`sql/migration_add_deleted_at.sql`

## ⚡ 故障排除

### 刪除房間時出現 404 錯誤

**原因：** 後端沒有 DELETE 端點或資料庫沒有遷移

**解決：**

1. 確認後端代碼已更新
2. 執行資料庫遷移
3. 重啟後端伺服器

### 房間刪除後仍然顯示

**原因：** 應用沒有刷新或快取沒清空

**解決：**

1. 關閉應用完全重啟
2. 清空應用快取
3. 檢查 get_rooms API 日誌

## 📞 需要幫助？

查看詳細指南：`SOFT_DELETE_GUIDE.md`
