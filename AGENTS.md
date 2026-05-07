# Life Tracker — Agent Guide

## Project
Single-page life-logging app (post-layoff journal from 23 Apr 2026). Built as a single HTML file — no build tools, no package manager, no npm.

## Stack (all CDN-loaded in index.html)
- React 18 (UMD), Tailwind CSS, Babel standalone (JSX transpilation), Lucide icons
- All dependencies loaded from unpkg/cdn.tailwindcss.com — no manifest or lockfile

## Local Storage Keys
- `lifetracker-v4-data` — all log entries (JSON array)
- `lifetracker-v4-cats` — user custom categories

## AWS Migration (in progress)
See `aws/` directory:
- `LifeTrackerHandler.py` — Python Lambda (boto3), handles GET (scan), POST/PUT (put_item), DELETE (delete_item)
- DynamoDB table: `LifeTrackerLogs` (partition key: `id`)
- API Gateway: HTTP API, route `ANY /LifeTrackerHandler`, no auth, CORS wide-open
- Frontend calls API Gateway URL directly via fetch
- Lambda expects payload shape `{ action?, data: { id, category, content, date, dayNumber, completed } }`
- Categories saved with `id = "CAT_" + name`

## Day Counting
Day 1 = 2026-04-23. Constant `DAY_ONE_STR` in the app.

## Default Categories
Todo (indigo), Meal (orange), Gym (emerald), Hiking (green), PTCG (teal), Note (slate). Protected from deletion.

## Data Backup
Upload/download JSON via header buttons. No automated backup.

## Skills
- `.opencode/skills/life-tracker-backend-test/SKILL.md` — integration test runner for the AWS backend (API Gateway + Lambda + DynamoDB). Load via the `skill` tool when asked to test the backend.
- `.opencode/skills/deploy-frontend/SKILL.md` — deploys `index.html` to S3, invalidates CloudFront, and runs backend tests. Load via the `skill` tool when asked to deploy to production.

## Deployment

After making local changes, deploy to AWS:

| File | Destination | Method |
|------|-------------|--------|
| `index.html` | S3 bucket (CloudFront origin) | Load skill: `skill("deploy-frontend")` |
| `aws/LifeTrackerHandler.py` | Lambda console | Paste code into Lambda editor → Deploy |

### Post-deploy verification
1. Open CloudFront URL — app loads from API (no error screen)
2. Add a log — appears in timeline
3. Toggle todo checkbox — status persists after page refresh
4. Add/delete a category — persists after refresh
5. Run the backend test skill: `skill("life-tracker-backend-test")` → all 16 pass

## Commands
None. Open `index.html` in a browser to run. No dev server, no tests, no linter.
