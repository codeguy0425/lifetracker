param(
    [string]$ApiUrl = "https://m83ifb26g0.execute-api.ap-east-1.amazonaws.com/LifeTrackerHandler"
)

$Passed = 0
$Failed = 0
$TestLogId = "999999"
$TestTodoId = "999888"
$TestCatName = "TestSkill"

function Test-Step {
    param([string]$Name, [ScriptBlock]$Block)
    try {
        & $Block
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:Passed++
    } catch {
        Write-Host "  [FAIL] $Name : $_" -ForegroundColor Red
        $script:Failed++
    }
}

function Write-TempJson {
    param([string]$Content)
    $tmp = Join-Path $env:TEMP "lftest_$([System.IO.Path]::GetRandomFileName()).json"
    Set-Content -Path $tmp -Value $Content -NoNewline -Encoding ASCII
    return $tmp
}

function Rest($method, $body) {
    $params = @{
        Uri = $ApiUrl
        Method = $method
        ContentType = "application/json"
    }
    if ($body) { $params['Body'] = $body }
    try {
        $resp = Invoke-RestMethod @params
        return @{ Success = $true; Data = $resp }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        $reader.Close()
        return @{ Success = $false; StatusCode = $statusCode; ErrorBody = $errorBody }
    }
}

Write-Host "=== Life Tracker Backend Tests ===" -ForegroundColor Cyan
Write-Host "Target: $ApiUrl`n" -ForegroundColor DarkGray

# --- 1. GET ---
Test-Step "GET returns items" {
    $r = Rest -method GET
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    if (-not ($r.Data.PSObject.Properties.Name -contains 'logs')) {
        throw "Response missing 'logs' key"
    }
}

# --- 2. POST: add log entry ---
Test-Step "POST: add log entry" {
    $json = (Write-TempJson ('{"data":{"id":"' + $TestLogId + '","category":"Note","content":"Test entry","date":"2026-05-08","dayNumber":16,"completed":false}}'))
    $body = Get-Content $json -Raw
    Remove-Item $json -Force
    $r = Rest -method POST -body $body
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    if ($r.Data.message -ne 'Success') { throw "Unexpected: $($r.Data)" }
}

# --- 3. Verify log appears ---
Test-Step "GET: log appears after POST" {
    $r = Rest -method GET
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    $match = $r.Data.logs | Where-Object { $_.id -eq $TestLogId }
    if (-not $match) { throw "Log id $TestLogId not found after POST" }
}

# --- 4. DELETE: by id ---
Test-Step "DELETE: log by id" {
    $json = (Write-TempJson ('{"id":"' + $TestLogId + '"}'))
    $body = Get-Content $json -Raw
    Remove-Item $json -Force
    $r = Rest -method DELETE -body $body
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
}

# --- 5. Verify log gone ---
Test-Step "GET: log gone after DELETE" {
    $r = Rest -method GET
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    $match = $r.Data.logs | Where-Object { $_.id -eq $TestLogId }
    if ($match) { throw "Log id $TestLogId still present after DELETE" }
}

# --- 6. POST: add Todo log ---
Test-Step "POST: add Todo log (completed: false)" {
    $json = (Write-TempJson ('{"data":{"id":"' + $TestTodoId + '","category":"Todo","content":"Test todo","date":"2026-05-08","dayNumber":16,"completed":false}}'))
    $body = Get-Content $json -Raw
    Remove-Item $json -Force
    $r = Rest -method POST -body $body
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    if ($r.Data.message -ne 'Success') { throw "Unexpected: $($r.Data)" }
}

# --- 7. Verify Todo log appears with completed: false ---
Test-Step "GET: Todo log exists with completed: false" {
    $r = Rest -method GET
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    $match = $r.Data.logs | Where-Object { $_.id -eq $TestTodoId }
    if (-not $match) { throw "Todo log $TestTodoId not found" }
    if ($match.completed -ne $false) { throw "Expected completed: false, got $($match.completed)" }
}

# --- 8. POST: toggle Todo to completed: true ---
Test-Step "POST: toggle Todo to completed: true" {
    $json = (Write-TempJson ('{"data":{"id":"' + $TestTodoId + '","category":"Todo","content":"Test todo","date":"2026-05-08","dayNumber":16,"completed":true}}'))
    $body = Get-Content $json -Raw
    Remove-Item $json -Force
    $r = Rest -method POST -body $body
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    if ($r.Data.message -ne 'Success') { throw "Unexpected: $($r.Data)" }
}

# --- 9. Verify completed: true persists ---
Test-Step "GET: Todo log has completed: true" {
    $r = Rest -method GET
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    $match = $r.Data.logs | Where-Object { $_.id -eq $TestTodoId }
    if (-not $match) { throw "Todo log $TestTodoId not found" }
    if ($match.completed -ne $true) { throw "Expected completed: true, got $($match.completed)" }
}

# --- 10. DELETE: cleanup Todo log ---
Test-Step "DELETE: cleanup Todo log" {
    $json = (Write-TempJson ('{"id":"' + $TestTodoId + '"}'))
    $body = Get-Content $json -Raw
    Remove-Item $json -Force
    $r = Rest -method DELETE -body $body
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
}

# --- 11. Verify Todo log gone ---
Test-Step "GET: Todo log gone after DELETE" {
    $r = Rest -method GET
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    $match = $r.Data.logs | Where-Object { $_.id -eq $TestTodoId }
    if ($match) { throw "Todo log $TestTodoId still present after DELETE" }
}

# --- 12. POST: add category ---
Test-Step "POST: add category (saveCategory)" {
    $json = (Write-TempJson ('{"action":"saveCategory","data":{"name":"' + $TestCatName + '","icon":"book","color":"bg-amber-500"}}'))
    $body = Get-Content $json -Raw
    Remove-Item $json -Force
    $r = Rest -method POST -body $body
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    if ($r.Data.message -ne 'Success') { throw "Unexpected: $($r.Data)" }
}

# --- 13. Verify category appears ---
Test-Step "GET: category appears after saveCategory" {
    $r = Rest -method GET
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    $match = $r.Data.logs | Where-Object { $_.id -eq "CAT_$TestCatName" }
    if (-not $match) { throw "Category CAT_$TestCatName not found after POST" }
}

# --- 14. DELETE: category via deleteCategory action ---
Test-Step "DELETE: category (deleteCategory action)" {
    $json = (Write-TempJson ('{"action":"deleteCategory","name":"' + $TestCatName + '"}'))
    $body = Get-Content $json -Raw
    Remove-Item $json -Force
    $r = Rest -method DELETE -body $body
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
}

# --- 15. Verify category gone ---
Test-Step "GET: category gone after deleteCategory" {
    $r = Rest -method GET
    if (-not $r.Success) { throw "HTTP $($r.StatusCode): $($r.ErrorBody)" }
    $match = $r.Data.logs | Where-Object { $_.id -eq "CAT_$TestCatName" }
    if ($match) { throw "Category CAT_$TestCatName still present after deleteCategory" }
}

# --- 16. Empty body on DELETE should 400 ---
Test-Step "DELETE: empty body returns 400" {
    $r = Rest -method DELETE -body "{}"
    if ($r.Success) { throw "Expected 400 error" }
    # Expecting 400
}

# --- Summary ---
Write-Host "`n=== Results ===" -ForegroundColor Cyan
Write-Host "  Passed: $Passed" -ForegroundColor Green
Write-Host "  Failed: $Failed" -ForegroundColor Red
if ($Failed -eq 0) {
    Write-Host "  All tests passed!" -ForegroundColor Green
} else {
    Write-Host "  Some tests failed." -ForegroundColor Red
}
exit $Failed
