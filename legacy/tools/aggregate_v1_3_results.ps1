param(
    [string]$ResultDir = "D:\PPG\verilog\jxa\ppg_system_integration\v1_3_runs",
    [string]$OutputJson = "D:\PPG\verilog\jxa\ppg_system_integration\v1_3_runs\aggregate.json"
)

$ErrorActionPreference = "Stop"
$scenarioNames = @{
    1 = "PPG-LONG-10-CYCLES"
    2 = "NO-RECHECK-CROSS-CONTROL"
    3 = "INPUT-LIGHT-STATIC-MATRIX"
    4 = "STARTUP-IDAC-CALIBRATION"
    5 = "NORMAL-IDAC-SLOW-TRACKING"
    6 = "PERIODIC-RECHECK-RECOVERY"
    7 = "ADC-NUMERIC-CODE-SCOREBOARD"
    8 = "IDAC-SNAPSHOT-EPOCH-BUS-ISOLATION"
    9 = "OWNER-IDENTITY-BACKPRESSURE"
    10 = "LIFECYCLE-FAULT-ADC-ANOMALY"
    11 = "PPG-ROBUSTNESS-CORNER-WAVEFORMS"
}
$stableScenarioByPrefix = @{
    "SID" = 4
    "TRK" = 5
    "RRC" = 6
    "NRE" = 2
    "ILM" = 3
    "ADCN" = 7
    "ISE" = 8
    "OIB" = 9
    "LFA" = 10
    "PRC" = 11
}

$artifacts = @()
$stablePass = @{}
$stableFail = @()
$stableNotClosed = @()
$jntFailures = @()

foreach ($entry in $scenarioNames.GetEnumerator() | Sort-Object Name) {
    $scenarioId = [int]$entry.Key
    $scenarioName = [string]$entry.Value
    $path = Join-Path $ResultDir ("{0}.result.log" -f $scenarioName)
    $text = if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Raw } else { "" }
    $jnt = @([regex]::Matches($text, 'TB_JNT_BASELINE\s+run=(\d+)\s+group=(\S+)\s+checked=(\d+)\s+pass=(\d+)\s+fail=(\d+)\s+required=(\d+).*?status=(PASS|FAIL|NOT_CLOSED)') | ForEach-Object {
        [pscustomobject]@{ run = [int]$_.Groups[1].Value; group = $_.Groups[2].Value; checked = [int]$_.Groups[3].Value; pass = [int]$_.Groups[4].Value; fail = [int]$_.Groups[5].Value; required = [int]$_.Groups[6].Value; status = $_.Groups[7].Value }
    })
    if ($jnt.Count -eq 0) {
        $jntFailures += [pscustomobject]@{ scenario = $scenarioName; reason = "missing JNT records" }
    }
    foreach ($record in $jnt) {
        if ($record.required -ne 52 -or $record.checked -ne 52 -or $record.pass -ne 52 -or $record.fail -ne 0 -or $record.status -ne "PASS") {
            $jntFailures += [pscustomobject]@{ scenario = $scenarioName; run = $record.run; checked = $record.checked; pass = $record.pass; fail = $record.fail; required = $record.required; status = $record.status }
        }
    }
    foreach ($match in [regex]::Matches($text, 'TB_STABLE_RESULT\s+index=(\d+)\s+id=(\S+)\s+status=(PASS|FAIL|NOT_CLOSED)')) {
        $stableId = $match.Groups[2].Value
        $status = $match.Groups[3].Value
        $prefix = ($stableId -split '-', 2)[0]
        if (-not $stableScenarioByPrefix.ContainsKey($prefix) -or $stableScenarioByPrefix[$prefix] -ne $scenarioId) { continue }
        if ($status -eq "PASS") { $stablePass[$stableId] = [pscustomobject]@{ id = $stableId; scenario = $scenarioName; selector = $scenarioId } }
        elseif ($status -eq "FAIL") { $stableFail += $stableId }
        else { $stableNotClosed += $stableId }
        if ($status -ne "PASS") {
            $jntFailures += [pscustomobject]@{ scenario = $scenarioName; stable_id = $stableId; status = $status; reason = "expected stable ID did not PASS in owning run" }
        }
    }
    $artifacts += [pscustomobject]@{ selector = $scenarioId; scenario = $scenarioName; path = $path; jnt_records = $jnt.Count }
}

$allStableIds = @($stablePass.Keys + $stableFail + $stableNotClosed | Sort-Object -Unique)
$missingExpected = @()
foreach ($prefix in $stableScenarioByPrefix.Keys) {
    $owner = $stableScenarioByPrefix[$prefix]
    $ownerName = $scenarioNames[$owner]
    $ownerPath = Join-Path $ResultDir ("{0}.result.log" -f $ownerName)
    if (-not (Test-Path -LiteralPath $ownerPath)) { $missingExpected += $prefix }
}

$status = if ($allStableIds.Count -eq 107 -and $stableFail.Count -eq 0 -and $stableNotClosed.Count -eq 0 -and $jntFailures.Count -eq 0) { "PASS" } else { "NOT_CLOSED" }
$summary = [pscustomobject]@{
    version = "V1.3"
    status = $status
    stable_union_count = $allStableIds.Count
    stable_pass_count = $stablePass.Count
    stable_fail_count = @($stableFail | Sort-Object -Unique).Count
    stable_not_closed_count = @($stableNotClosed | Sort-Object -Unique).Count
    jnt_failure_count = $jntFailures.Count
    missing_expected_scenario_prefixes = $missingExpected
    jnt_failures = $jntFailures
    artifacts = $artifacts
}
$json = $summary | ConvertTo-Json -Depth 8
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputJson) | Out-Null
Set-Content -LiteralPath $OutputJson -Value $json -Encoding UTF8
$summary | Format-List
if ($status -ne "PASS") { exit 2 }
