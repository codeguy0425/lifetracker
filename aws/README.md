# AWS Backend — Life Tracker

## Architecture Overview

```
CloudFront (CDN)           API Gateway (HTTP API)
   |                             |
   v                             v
index.html  ──fetch────> Lambda (Python 3.x)
                              |
                              v
                         DynamoDB (LifeTrackerLogs)
```

The frontend (`index.html`) stores data in `localStorage` by default. The AWS migration adds API Gateway as a cloud backend, with a Lambda function (Python/boto3) reading/writing to a DynamoDB table.

---

## Lambda Function

**File:** `LifeTrackerHandler.py`

**Runtime:** Python 3.x (boto3 included in AWS Lambda environment)

**Handler:** `lambda_handler(event, context)`

### Event Method Detection

Handles both HTTP API v2 (`requestContext.http.method`) and REST API (`httpMethod`) event structures:

```python
method = event.get('requestContext', {}).get('http', {}).get('method') or event.get('httpMethod')
```

### Endpoints

| Method   | Behavior                                                                    |
|----------|-----------------------------------------------------------------------------|
| `OPTIONS`| Returns 200 with CORS headers (preflight)                                   |
| `GET`    | `table.scan()` — returns all items as `{ "logs": [...] }`                   |
| `POST`   | `put_item()` — creates or updates a log or category entry                   |
| `PUT`    | Same as POST (`put_item()`)                                                 |
| `DELETE` | `delete_item(Key={'id': ...})` — deletes by `id`, or by `action: "deleteCategory"` + `name` |
| Other    | Returns 405                                                                 |

### Request/Response Contract

**POST/PUT request body:**
```json
{
  "action": "saveCategory",
  "data": {
    "id": 1745432100000,
    "category": "Meal",
    "content": "breakfast: oatmeal",
    "date": "2026-05-08",
    "dayNumber": 16,
    "completed": false
  }
}
```

| Field       | Required | Type    | Notes                                       |
|-------------|----------|---------|---------------------------------------------|
| `data`      | Yes      | object  | Wraps the actual item                       |
| `action`    | No       | string  | If `"saveCategory"`, generates `id` as `CAT_<name>` |

**GET response:**
```json
{
  "logs": [
    { "id": 12345, "category": "Meal", "content": "...", "date": "2026-05-08", "dayNumber": 16, "completed": false }
  ]
}
```

**DELETE request body:**

Delete a log entry by ID:
```json
{ "id": 12345 }
```

Delete a category by name (explicit action):
```json
{ "action": "deleteCategory", "name": "Reading" }
```

### CORS Headers (all responses)
```json
{
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS"
}
```

### Error Handling

- Missing `data` key on POST/PUT → 400 `{ "error": "Missing data key" }`
- Missing `id` on DELETE (or missing `name` for `deleteCategory` action) → 400 `{ "error": "Missing id for deletion" }`
- Missing request body on DELETE → 400 `{ "error": "Missing request body" }`
- All unhandled exceptions → 500 `{ "error": "<exception message>" }`
- Unsupported HTTP method → 405 `{ "error": "Method <X> not allowed" }`

### Decimal Serialization

DynamoDB returns `Decimal` types for numeric fields. A custom `DecimalEncoder` converts them to `float` during JSON serialization.

---

## DynamoDB

**Table name:** `LifeTrackerLogs`

**Partition key:** `id` (String/Number — Lambda treats it opaquely)

No sort key, no secondary indexes configured.

### Item Schema

| Attribute   | Type    | Example              | Notes                                  |
|-------------|---------|----------------------|----------------------------------------|
| `id`        | Number  | `1745432100000`      | `Date.now()` from frontend; or `CAT_<name>` for categories |
| `category`  | String  | `"Meal"`             | One of the defined categories          |
| `content`   | String  | `"breakfast: ..."`   | Free-text log content with newlines    |
| `date`      | String  | `"2026-05-08"`       | ISO date string (YYYY-MM-DD)           |
| `dayNumber` | Number  | `16`                 | Days since 2026-04-23 (Day 1)          |
| `completed` | Boolean | `false`              | Only meaningful for `Todo` category    |

### Category Entries

Categories are stored as regular items with `id = "CAT_" + name`:

```json
{
  "id": "CAT_Hiking",
  "name": "Hiking",
  "icon": "mountain",
  "color": "bg-green-700",
  "protected": true
}
```

### Sample Data

| id            | category | completed | content                              | date       | dayNumber |
|---------------|----------|-----------|--------------------------------------|------------|-----------|
| `1.77805E+12` | Meal     | false     | `"breakfast: ... \nlunch: n/a\n..."` | `23/5/2026`| 31        |
| `1.77805E+12` | Note     | false     | `"timer"`                            | `23/4/2026`| 1         |

Note: The sample dates are in DD/MM/YYYY format, but the application sends ISO format (YYYY-MM-DD).

---

## API Gateway

**Type:** HTTP API (no custom domain, no auth)

**Endpoint (from config):** `https://m83ifb26g0.execute-api.ap-east-1.amazonaws.com`

**Route:** `ANY /LifeTrackerHandler`

| Detail         | Value                                   |
|----------------|-----------------------------------------|
| Route ID       | `gmxqg7h`                               |
| Integration ID | `rwaxp65`                                |
| Region         | `ap-east-1` (Hong Kong)                 |
| Authorizer     | None (open endpoint)                     |

CORS is handled entirely by the Lambda function. No CORS configuration is needed at the API Gateway level.

---

## Frontend Integration

The frontend (`index.html`) does **not** currently include API Gateway calls — the AWS migration is in progress. When integrated, the expected flow is:

1. **Load:** `GET /LifeTrackerHandler` → `{ logs: [...] }` → populate app state
2. **Create/Update:** `POST /LifeTrackerHandler` with `{ data: { id, category, content, date, dayNumber, completed } }`
3. **Delete Log:** `DELETE /LifeTrackerHandler` with `{ id: <number> }`
4. **Save Category:** `POST /LifeTrackerHandler` with `{ action: "saveCategory", data: { name, icon, color } }`
5. **Delete Category:** `DELETE /LifeTrackerHandler` with `{ action: "deleteCategory", name: "<name>" }`

The Lambda expects a **wrapped payload** (`data` key), not the item at the top level — this is the current contract.

---

## Testing with curl (Windows)

Replace the API URL with your deployed endpoint.

```powershell
# Add a log entry
curl.exe -X POST "https://m83ifb26g0.execute-api.ap-east-1.amazonaws.com/LifeTrackerHandler" `
  -H "Content-Type: application/json" `
  -d '{"data":{"id":1,"category":"Note","content":"test entry","date":"2026-05-08","dayNumber":16,"completed":false}}'

# Add a category
curl.exe -X POST "https://m83ifb26g0.execute-api.ap-east-1.amazonaws.com/LifeTrackerHandler" `
  -H "Content-Type: application/json" `
  -d '{"action":"saveCategory","data":{"name":"Reading","icon":"book","color":"bg-amber-500"}}'

# Fetch all items
curl.exe -s "https://m83ifb26g0.execute-api.ap-east-1.amazonaws.com/LifeTrackerHandler"

# Delete a log entry by ID
curl.exe -X DELETE "https://m83ifb26g0.execute-api.ap-east-1.amazonaws.com/LifeTrackerHandler" `
  -H "Content-Type: application/json" `
  -d '{"id":1}'

# Delete a category by name (explicit action)
curl.exe -X DELETE "https://m83ifb26g0.execute-api.ap-east-1.amazonaws.com/LifeTrackerHandler" `
  -H "Content-Type: application/json" `
  -d '{"action":"deleteCategory","name":"Reading"}'
```

> Use `curl.exe` (not `curl`) on Windows to avoid PowerShell's `Invoke-WebRequest` alias. Backtick `` ` `` is the PowerShell line continuation character.

---

## Deployment Notes

- Lambda must have IAM policy allowing `dynamodb:Scan`, `dynamodb:PutItem`, `dynamodb:DeleteItem` on `LifeTrackerLogs`
- No VPC required (Lambda accesses DynamoDB via AWS service endpoint)
- Environment variables could be used for `TABLE_NAME` but are currently hardcoded
- CloudFront is planned for hosting `index.html` but not yet configured
