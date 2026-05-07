<#
.SYNOPSIS
    Deploy LifeTrackerHandler Lambda function: zip and upload via AWS CLI.
.DESCRIPTION
    Zips aws/LifeTrackerHandler.py and runs lambda update-function-code.
    Polls until the update completes.
.EXAMPLE
    .\deploy-lambda.ps1
.NOTES
    Requires AWS CLI configured and lambda:UpdateFunctionCode IAM permission.
#>

$ErrorActionPreference = "Stop"
$script:projectRoot = Resolve-Path "$PSScriptRoot\..\..\.."
$script:lambdaFile = Join-Path $script:projectRoot "aws\LifeTrackerHandler.py"
$script:functionName = "LifeTrackerHandler"

function Write-Step($message) {
    Write-Host "`n==> $message" -ForegroundColor Cyan
}

function Write-Success($message) {
    Write-Host "  OK  $message" -ForegroundColor Green
}

function Write-Fail($message) {
    Write-Host "  FAIL  $message" -ForegroundColor Red
}

function Check-Exit($stepName) {
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "$stepName exited with code $LASTEXITCODE"
        exit 1
    }
}

# ---- Check prerequisites ----
Write-Step "Checking prerequisites"

if (-not (Get-Command "aws" -ErrorAction SilentlyContinue)) {
    Write-Fail "AWS CLI not found. Install it first: winget install Amazon.AWSCLI"
    exit 1
}
Write-Success "AWS CLI found"

if (-not (Test-Path $lambdaFile)) {
    Write-Fail "Lambda source not found at $lambdaFile"
    exit 1
}
Write-Success "Found $lambdaFile"

# ---- Zip the Python file ----
Write-Step "Packaging Lambda code"

$tempZip = Join-Path $env:TEMP "LifeTrackerHandler_$(Get-Date -Format yyyyMMdd_HHmmss).zip"
if (Test-Path $tempZip) { Remove-Item -Force $tempZip }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($tempZip, [System.IO.Compression.ZipArchiveMode]::Create)
$null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $lambdaFile, "LifeTrackerHandler.py")
$zip.Dispose()

Write-Success "Created $tempZip"

# ---- Update Lambda code ----
Write-Step "Updating Lambda function: $functionName"

$updateResult = aws lambda update-function-code `
    --function-name $functionName `
    --zip-file "fileb://$tempZip" `
    --output json 2>&1
Check-Exit "lambda update-function-code"

$parsed = $updateResult | ConvertFrom-Json
$script:newVersion = $parsed.Version
Write-Success "Update submitted (version $($script:newVersion))"

# ---- Poll for completion ----
Write-Step "Waiting for update to complete"
$maxWait = 60
$waited = 0
do {
    Start-Sleep -Seconds 3
    $waited += 3
    $status = aws lambda get-function-configuration --function-name $functionName --output json 2>&1 | ConvertFrom-Json
    $updateStatus = $status.LastUpdateStatus
    $updateReason = $status.LastUpdateStatusReason
    if ($updateStatus -eq "Successful") {
        Write-Success "Update completed in ${waited}s"
        break
    } elseif ($updateStatus -eq "Failed") {
        Write-Fail "Update failed: $updateReason"
        exit 1
    }
    Write-Host "  ... $updateStatus ($waited s)" -ForegroundColor Gray
} while ($waited -lt $maxWait)

if ($status.LastUpdateStatus -ne "Successful") {
    Write-Fail "Update did not complete within ${maxWait}s. Check AWS console."
    exit 1
}

# ---- Cleanup ----
Remove-Item -Force $tempZip -ErrorAction SilentlyContinue

# ---- Summary ----
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       LAMBDA DEPLOY SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Function: $functionName" -ForegroundColor White
Write-Host "  Version:  $($script:newVersion)" -ForegroundColor White
Write-Host "  Source:   $($lambdaFile)" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

exit 0
