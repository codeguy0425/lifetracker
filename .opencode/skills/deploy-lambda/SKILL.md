---
name: deploy-lambda
description: Zip and upload LifeTrackerHandler.py to AWS Lambda via CLI.
---

## When to use me

Use this skill when asked to deploy Lambda changes, update the backend code, or when `LifeTrackerHandler.py` has been modified and needs to go live.

## What I do

1. Zip `aws/LifeTrackerHandler.py`
2. Run `aws lambda update-function-code`
3. Poll until deployment completes (up to 60s)
4. Report new version number

---

## One-time setup

Lambda function `LifeTrackerHandler` must already exist in AWS console. No additional setup needed.

Required IAM permission: `lambda:UpdateFunctionCode` on `LifeTrackerHandler`.

---

## Standalone usage

From the project root:

```powershell
powershell -File ".opencode/skills/deploy-lambda/deploy-lambda.ps1"
```

## Integrated usage

Run the full stack deploy to update Lambda + frontend together:

```powershell
powershell -File ".opencode/skills/deploy-frontend/deploy.ps1"
```

This runs: git commit+push → S3 → CloudFront → **Lambda update** → backend tests

## Notes

- Only updates the code. Environment variables, triggers, and configuration are preserved.
- If syntax errors exist, `update-function-code` still succeeds — they only surface on invoke. Backend tests catch this.
- Lambda update runs before backend tests, so tests validate the live backend.
