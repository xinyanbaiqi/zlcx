param(
    [string]$Snapshot = "tb_ppg_scheduler_ssw_ami_integration_scenarios_sim",
    [string]$OutputDir = "D:\PPG\verilog\jxa\ppg_system_integration\v1_3_runs",
    [switch]$SkipLong,
    [string]$ScenarioIds = ""
)

$ErrorActionPreference = "Stop"
$workDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$xsim = "C:\Xilinx\Vivado\2022.2\bin\xsim.bat"

$scenarios = @(
    @{ Id = 1; Name = "PPG-LONG-10-CYCLES" },
    @{ Id = 2; Name = "NO-RECHECK-CROSS-CONTROL" },
    @{ Id = 3; Name = "INPUT-LIGHT-STATIC-MATRIX" },
    @{ Id = 4; Name = "STARTUP-IDAC-CALIBRATION" },
    @{ Id = 5; Name = "NORMAL-IDAC-SLOW-TRACKING" },
    @{ Id = 6; Name = "PERIODIC-RECHECK-RECOVERY" },
    @{ Id = 7; Name = "ADC-NUMERIC-CODE-SCOREBOARD" },
    @{ Id = 8; Name = "IDAC-SNAPSHOT-EPOCH-BUS-ISOLATION" },
    @{ Id = 9; Name = "OWNER-IDENTITY-BACKPRESSURE" },
    @{ Id = 10; Name = "LIFECYCLE-FAULT-ADC-ANOMALY" },
    @{ Id = 11; Name = "PPG-ROBUSTNESS-CORNER-WAVEFORMS" }
)

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
if ($SkipLong) { $scenarios = $scenarios | Where-Object { $_.Id -ne 1 } }
if ($ScenarioIds -ne "") {
    $selectedIds = @($ScenarioIds -split "," | ForEach-Object { [int]$_.Trim() })
    $scenarios = $scenarios | Where-Object { $selectedIds -contains $_.Id }
}

if ($scenarios.Count -eq 0) {
    throw "No scenarios selected. Use -ScenarioIds 2,3 or omit it to run the full set."
}

foreach ($scenario in $scenarios) {
    $resultFile = Join-Path $OutputDir ("{0}.result.log" -f $scenario.Name)
    $xsimLog = Join-Path $OutputDir ("{0}.xsim.log" -f $scenario.Name)
    $defaultResultFile = Join-Path $workDir "tb_scenario_result.log"
    Remove-Item -LiteralPath $resultFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $xsimLog -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $defaultResultFile -Force -ErrorAction SilentlyContinue

    Write-Host ("RUN scenario={0} id={1}" -f $scenario.Name, $scenario.Id)
    Push-Location $workDir
    try {
        & $xsim $Snapshot --runall --testplusarg ("SCENARIO{0}" -f $scenario.Id) 2>&1 | Tee-Object -FilePath $xsimLog
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    if ($exitCode -ne 0) {
        Write-Warning ("xsim returned {0} for {1}; result artifact is retained" -f $exitCode, $scenario.Name)
    }
    if (-not (Test-Path -LiteralPath $resultFile)) {
        if (Test-Path -LiteralPath $defaultResultFile) {
            Copy-Item -LiteralPath $defaultResultFile -Destination $resultFile -Force
        }
        else {
            Write-Warning ("missing result artifact for {0}" -f $scenario.Name)
        }
    }
    if (Test-Path -LiteralPath $resultFile) {
        $artifactText = Get-Content -LiteralPath $resultFile -Raw
        if ($artifactText -notmatch "TB_JNT_BASELINE") {
            Write-Warning ("{0} completed without a JNT artifact; retain as NOT_CLOSED" -f $scenario.Name)
        }
    }
}

Write-Host ("Scenario batch complete: {0}. Invoke aggregate_v1_3_results.ps1 against the output directory." -f (($scenarios | ForEach-Object { $_.Id }) -join ","))
