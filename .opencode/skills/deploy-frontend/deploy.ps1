<#
.SYNOPSIS
    Deploy Life Tracker to production: git commit+push, S3 upload, CloudFront invalidation, backend tests.
.DESCRIPTION
    Automates the full deploy pipeline:
    1. Stage all changes and git commit with auto-generated message
    2. Push to GitHub (origin main)
    3. Upload index.html to S3
    4. Invalidate CloudFront cache
    5. Run backend integration tests
.EXAMPLE
    .\deploy.ps1
.NOTES
    Requires AWS CLI configured and git remote set up.
#>

$ErrorActionPreference = "Stop"
$originalLocation = Get-Location
$script:exitCode = 0
$script:commitHash = $null
$script:gitSkipped = $false
$script:s3Result = $null
$script:cfResult = $null
$script:testResult = $null

function Write-Step($message) {
    Write-Host "`n==> $message" -ForegroundColor Cyan
}

function Write-Success($message) {
    Write-Host "  OK  $message" -ForegroundColor Green
}

function Write-Fail($message) {
    Write-Host "  FAIL  $message" -ForegroundColor Red
    $script:exitCode = 1
}

function Check-Exit($stepName) {
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "$stepName exited with code $LASTEXITCODE"
        exit 1
    }
}

# ---- 0. Prerequisites ----
Write-Step "Checking prerequisites"

# Check AWS CLI
$awsPath = Get-Command "aws" -ErrorAction SilentlyContinue
if (-not $awsPath) {
    $candidate = "C:\Program Files\Amazon\AWSCLIV2\aws.exe"
    if (Test-Path $candidate) {
        $env:Path += ";C:\Program Files\Amazon\AWSCLIV2"
        $awsPath = Get-Command "aws" -ErrorAction SilentlyContinue
    }
}
if (-not $awsPath) {
    Write-Fail "AWS CLI not found. Install it first:"
    Write-Fail "  winget install Amazon.AWSCLI"
    Write-Fail "  Then run: aws configure"
    exit 1
}
Write-Success "AWS CLI found"

# Check git
if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
    Write-Fail "git not found. Install Git for Windows from https://git-scm.com/"
    exit 1
}
Write-Success "git found"

# Check we're in a git repo
git rev-parse --git-dir 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Not a git repository. Run 'git init' first."
    exit 1
}

# ---- 1. Git commit ----
Write-Step "Staging changes"

git add -A
$hasChanges = git diff --cached --quiet 2>$null; $hasChanges = -not $?
if ($hasChanges) {
    $dateStr = Get-Date -Format "yyyy-MM-dd_HHmm"
    $msg = "deploy: auto-sync $dateStr"
    Write-Step "Committing: $msg"
    git commit -m $msg
    Check-Exit "git commit"
    $script:commitHash = git log --format="%h" -1
    Write-Success "Committed $($script:commitHash)"
} else {
    Write-Success "No changes to commit"
    $script:gitSkipped = $true
}

# ---- 2. Git push ----
if (-not $script:gitSkipped) {
    Write-Step "Pushing to GitHub"
    $remote = git remote get-url origin 2>$null
    if (-not $remote) {
        Write-Fail "No remote 'origin' configured. Add one first:"
        Write-Fail "  git remote add origin https://github.com/<user>/<repo>.git"
        exit 1
    }
    git push origin main
    Check-Exit "git push"
    Write-Success "Pushed to $remote"
}

# ---- 3. S3 upload ----
Write-Step "Uploading index.html to S3"
aws s3 cp index.html s3://codeguy-life-tracker/index.html
Check-Exit "s3 cp"
$script:s3Result = "uploaded"

# ---- 4. CloudFront invalidation ----
Write-Step "Invalidating CloudFront cache"
$cfOutput = aws cloudfront create-invalidation --distribution-id E1EW27NJQU3B33 --paths "/index.html" --output json 2>&1
Check-Exit "cloudfront create-invalidation"
$cfParsed = $cfOutput | ConvertFrom-Json
$script:cfResult = $cfParsed.Invalidation.Id
Write-Success "Invalidation created: $($script:cfResult)"

# ---- 5. Backend tests ----
Write-Step "Running backend tests"
$testDir = Join-Path $PSScriptRoot "..\life-tracker-backend-test"
$testScript = Join-Path $testDir "test-backend.ps1"
if (-not (Test-Path $testScript)) {
    Write-Fail "Test script not found at $testScript"
    exit 1
}
& $testScript
$script:testResult = if ($LASTEXITCODE -eq 0) { "passed" } else { "FAILED" }

# ---- Summary ----
Write-Host "`n" -NoNewline
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "         DEPLOY SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
if (-not $script:gitSkipped) {
    Write-Host "  Commit:    $($script:commitHash)" -ForegroundColor White
} else {
    Write-Host "  Commit:    (none, no changes)" -ForegroundColor Yellow
}
Write-Host "  S3 upload: $($script:s3Result)" -ForegroundColor White
Write-Host "  CF inval:  $($script:cfResult)" -ForegroundColor White
Write-Host "  Tests:     $($script:testResult)" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($script:exitCode -ne 0) {
    exit $script:exitCode
}

if ($script:testResult -ne "passed") {
    Write-Host "WARNING: Tests did not pass. Deploy may be incomplete." -ForegroundColor Yellow
    exit 1
}

Write-Host "Deploy complete." -ForegroundColor Green
exit 0
