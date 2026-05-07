---
name: life-tracker-backend-test
description: Run integration tests against the Life Tracker AWS backend (API Gateway, Lambda, DynamoDB) via the PowerShell test script.
---

## What I do

Run the PowerShell integration test script that exercises all API Gateway endpoints:
- GET (scan all items)
- POST (create log entry)
- POST (toggle todo completed status)
- DELETE (delete log by id)
- POST (save category via `saveCategory` action)
- DELETE (delete category via `deleteCategory` action)
- Error case (empty body returns 400)

## When to use me

Use this skill when asked to test the backend API, verify the Lambda function, or run integration tests against the deployed Life Tracker API.

## How to run

Execute the test script from the project root:

```powershell
powershell -File ".opencode/skills/life-tracker-backend-test/test-backend.ps1"
```

To target a different API endpoint:

```powershell
powershell -File ".opencode/skills/life-tracker-backend-test/test-backend.ps1" -ApiUrl "https://your-url/LifeTrackerHandler"
```

## What the script tests

| Test | Endpoint | Expected |
|------|----------|----------|
| GET returns logs | `GET /LifeTrackerHandler` | Response has `logs` key |
| POST log entry | `POST /LifeTrackerHandler` | 200 |
| Verify log persisted | `GET /LifeTrackerHandler` | Log with matching id exists |
| DELETE log by id | `DELETE /LifeTrackerHandler` | 200 |
| Verify log deleted | `GET /LifeTrackerHandler` | Log with matching id gone |
| POST Todo log (completed: false) | `POST /LifeTrackerHandler` | 200 |
| Verify Todo log exists | `GET /LifeTrackerHandler` | `completed` is `false` |
| POST toggle Todo to true | `POST /LifeTrackerHandler` | 200 |
| Verify toggle persisted | `GET /LifeTrackerHandler` | `completed` is `true` |
| DELETE cleanup Todo log | `DELETE /LifeTrackerHandler` | 200 |
| Verify Todo log gone | `GET /LifeTrackerHandler` | Log with matching id gone |
| POST category (saveCategory) | `POST /LifeTrackerHandler` | 200 |
| Verify category persisted | `GET /LifeTrackerHandler` | Item with `CAT_<name>` id exists |
| DELETE category (deleteCategory) | `DELETE /LifeTrackerHandler` | 200 |
| Verify category deleted | `GET /LifeTrackerHandler` | Item with `CAT_<name>` id gone |
| Empty body returns 400 | `DELETE /LifeTrackerHandler` | 400 |
