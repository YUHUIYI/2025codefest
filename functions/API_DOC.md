# Sports Voucher API Documentation

Base URL (Production): `https://api-ffuxb6ym4q-de.a.run.app`

> All endpoints are prefixed with the base URL above. Example: `GET https://api-ffuxb6ym4q-de.a.run.app/stores`

## Authentication
Currently no authentication is required. All requests accept and return JSON.

---

## Endpoints

### 1. Health Check
- **Method**: `GET`
- **Path**: `/health`
- **Description**: Returns a simple status payload to verify the function is alive.

#### Example
```bash
curl "https://api-ffuxb6ym4q-de.a.run.app/health"
```

**Sample Response**
```json
{
  "status": "ok",
  "timestamp": "2025-11-08T02:30:00.123Z"
}
```

---

### 2. List Active Stores
- **Method**: `GET`
- **Path**: `/stores`
- **Description**: Returns every store where `is_active === true`.

#### Example
```bash
curl "https://api-ffuxb6ym4q-de.a.run.app/stores"
```

---

### 3. Get Store By ID
- **Method**: `GET`
- **Path**: `/stores/{storeId}`
- **Description**: Fetch a single store document by Firestore document ID.

#### Example
```bash
curl "https://api-ffuxb6ym4q-de.a.run.app/stores/123"
```

---

### 4. Filter Stores
- **Method**: `GET`
- **Path**: `/stores/filter`
- **Query Parameters** (all optional):
  - `category`: exact match on store category
  - `usable_item`: item inside `usable_items` array
  - `minPrice`, `maxPrice`: numeric filters on `price_range`
  - `lat`, `lng`: user coordinates used for distance sort
  - `radius`: maximum distance (km) when `lat/lng` provided
  - `liked`: `true` together with `userId` to filter liked stores
  - `userId`: user identifier for liked filtering

#### Example
```bash
curl "https://api-ffuxb6ym4q-de.a.run.app/stores/filter?category=%E9%81%8B%E5%8B%95%E5%A0%B4%E9%A4%A8-%E7%91%9C%E7%92%A7&lat=25.04&lng=121.56&radius=5"
```

---

### 5. Toggle Like
- **Method**: `POST`
- **Path**: `/stores/{storeId}/like`
- **Body**:
  ```json
  {
    "userId": "user-123"
  }
  ```
- **Description**: Adds/removes `userId` from the store document `likedBy` array.

#### Example
```bash
curl -X POST \
  "https://api-ffuxb6ym4q-de.a.run.app/stores/123/like" \
  -H "Content-Type: application/json" \
  -d '{"userId":"user-123"}'
```

---

### 6. Add or Update Fields
- **Method**: `POST`
- **Path**: `/stores/{storeId}/fields`
- **Body**: JSON object, keys are field names, values are written directly to Firestore. Existing fields are overwritten.

#### Example
```bash
curl -X POST \
  "https://api-ffuxb6ym4q-de.a.run.app/stores/123/fields" \
  -H "Content-Type: application/json" \
  -d '{
        "extra_note": "需提前預約",
        "website": "https://example.com",
        "is_active": true
      }'
```
- **Response**: `{ "success": true, "message": "Fields added or updated successfully" }`

---

### 7. Update Existing Fields
- **Method**: `PATCH`
- **Path**: `/stores/{storeId}`
- **Body**: JSON object with fields already present in the document (e.g. `is_active`, `website`). Any new/unknown fields trigger a 400 response.

#### Example
```bash
curl -X PATCH \
  "https://api-ffuxb6ym4q-de.a.run.app/stores/123" \
  -H "Content-Type: application/json" \
  -d '{
        "is_active": false,
        "website": "https://new-site.tw"
      }'
```
- **Response**: `{ "success": true, "message": "Store updated successfully" }`

---

### 8. List Products
- **Method**: `GET`
- **Path**: `/products`
- **Description**: Returns all products and their associated store linkage. Each item includes:
  - `id`: Product document ID
  - `product_name`: Product display name
  - `price`: Numeric price (defaults to `0` if missing/invalid)
  - `store_id`: Related store document ID
  - `store_name`: Store display name

#### Example
```bash
curl "https://api-ffuxb6ym4q-de.a.run.app/products"
```

**Sample Response**
```json
{
  "success": true,
  "count": 2,
  "data": [
    {
      "id": "prod-001",
      "product_name": "活動咖三折旅行包",
      "price": 268,
      "store_id": "1",
      "store_name": "EventPal 活動咖運動報名平台"
    },
    {
      "id": "prod-002",
      "product_name": "拳擊體驗課程",
      "price": 499,
      "store_id": "store_abc",
      "store_name": "Knockout Boxing 台北"
    }
  ]
}
```

---

## Local Development & Testing

### 1. Install Dependencies
```bash
cd functions
npm install
```

### 2. Start Firebase Emulator Suite
```bash
npm run serve
```
- Functions base URL becomes `http://127.0.0.1:5001/dongzhi-taipei/asia-east1/api`
- Example request: `curl http://127.0.0.1:5001/dongzhi-taipei/asia-east1/api/stores`

### 3. Emulator UI
- When running locally, open `http://127.0.0.1:4000` to inspect Firestore documents, logs, and function calls.

### 4. Testing with Postman or Thunder Client
- Import the API endpoints above into a collection
- Set `Content-Type: application/json` for POST/PATCH calls
- Body format is identical for local and production URLs

---

## Deployment
1. Build functions (TypeScript -> JavaScript)
   ```bash
   cd functions
   npm run build
   ```
2. Deploy the `api` function
   ```bash
   firebase deploy --only functions:api
   ```

> Note: Deployment logs may warn about artifact cleanup policy. Run `firebase functions:artifacts:setpolicy` once if you want Firebase to automatically clean old container images.

---

## Change Log
- **2025-11-09**: Added `/products` endpoint documentation and `/health` health check section.
- **2025-11-08**: Added `/stores/:id/fields` for adding custom fields and `/stores/:id` (PATCH) for updating existing fields.
