---
name: deploy-frontend
description: Deploy index.html to S3, invalidate CloudFront cache, then verify backend tests pass.
---

## When to use me

Use this skill when asked to deploy frontend changes, push to production, or sync local `index.html` to AWS.

## What I do

1. Git commit all staged/unstaged changes with auto-generated message
2. Push to GitHub (`origin main`)
3. Upload `index.html` to S3 bucket
4. Invalidate the CloudFront cache for `/index.html`
5. Run the backend test suite to verify nothing is broken

---

## One-time setup

If this is a fresh clone or git isn't initialized yet:

```powershell
git init
git checkout -b main
git add -A
git commit -m "initial commit"
git remote add origin <your-github-repo-url>
git push -u origin main
```

Prerequisites:
- **AWS CLI:** `winget install Amazon.AWSCLI` then `aws configure`
- **Git:** Install from https://git-scm.com/
- **IAM permissions:** `s3:PutObject` on `codeguy-life-tracker`, `cloudfront:CreateInvalidation` on `E1EW27NJQU3B33`

---

## Automated deploy (recommended)

From the project root:

```powershell
powershell -File ".opencode/skills/deploy-frontend/deploy.ps1"
```

The script handles everything: git commit → push → S3 → CloudFront → tests.

---

## Manual deploy (alternative)

```powershell
# Ensure AWS CLI is on PATH (first session after install)
$env:Path += ";C:\Program Files\Amazon\AWSCLIV2"

# 1. Git commit + push
git add -A
git commit -m "deploy: <brief description>"
git push origin main

# 2. Upload to S3
aws s3 cp index.html s3://codeguy-life-tracker/index.html

# 3. Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id E1EW27NJQU3B33 --paths "/index.html"

# 4. Verify backend
powershell -File ".opencode/skills/life-tracker-backend-test/test-backend.ps1"
```

All 16 tests should pass. If any fail, investigate before declaring the deploy complete.

## Notes

- Only deploys `index.html`. Lambda updates require a separate manual step via the AWS Lambda console.
- Requires AWS CLI to be installed and configured (`aws configure`).
- The automated script exits with non-zero if any step fails.
