# guardian.ps1 — Windows native adapter for the post-deploy guardian (B2).
#
# Mirrors guardian/guardian.sh (POSIX) behavior one-to-one:
#   - hourly heartbeat via schtasks (no resident daemon)
#   - read-only SHA256 baseline patrol (Get-FileHash)
#   - 3-level anomaly classification: info / warn / fault
#   - static receipt page at ~\.guardian\page\receipt.html
#   - one-command clean uninstall (removes scheduled task + all files)
#
# Design contract (v0):
#   - outbound-only: no inbound ports opened, ever. Reporting via
#     Invoke-WebRequest (client-side POST) only, and only when
#     GUARDIAN_WEBHOOK_URL is set; failure never blocks.
#   - read-only checks: never modifies the guarded system.
#   - drift is recorded, not fixed (auto-repair is out of scope for v0).
#   - privacy: payloads carry fingerprints and levels only, never file contents.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File guardian.ps1 <command>
#   commands: baseline add <file> | baseline list | patrol
#             heartbeat run|start|stop|cron | page | uninstall | help

$ErrorActionPreference = 'Stop'

# ---- paths (all under one root for clean uninstall) --------------------------
$GuardianHome = if ($env:GUARDIAN_HOME) { $env:GUARDIAN_HOME } else { Join-Path $HOME ".guardian" }
$BaselineDir  = Join-Path $GuardianHome "baseline"
$StateDir     = Join-Path $GuardianHome "state"
$ReportsDir   = Join-Path $GuardianHome "reports"
$PageDir      = Join-Path $GuardianHome "page"
$LogFile      = Join-Path $GuardianHome "guardian.log"
$TaskName     = "DeployKitGuardianHeartbeat"
$Version      = if ($env:GUARDIAN_VERSION) { $env:GUARDIAN_VERSION } else { "v0" }

function Write-GuardianLog {
    param([string]$Message)
    $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    [System.IO.File]::AppendAllText($LogFile, "[$stamp] $Message`r`n")
}

function Initialize-GuardianDirs {
    foreach ($d in @($BaselineDir, $StateDir, $ReportsDir, $PageDir)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
}

function Send-GuardianWebhook {
    # Outbound-only POST of the event payload; failure never blocks.
    param([string]$PayloadJson)
    if (-not $env:GUARDIAN_WEBHOOK_URL) { return }
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $env:GUARDIAN_WEBHOOK_URL `
            -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($PayloadJson)) `
            -ContentType "application/json" -TimeoutSec 10 | Out-Null
    } catch {
        Write-GuardianLog "webhook skipped (unreachable)"
    }
}

function Get-NowIso {
    return (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
}

function Get-PathFingerprint {
    # SHA256 of the file content (core fingerprint primitive).
    param([string]$Path)
    if (-not (Test-Path $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
}

function Get-PathId {
    # 16-hex id for a path; matches POSIX (sha256 of the path string + newline).
    param([string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Path -replace '\\', '/') + "`n")
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLower().Substring(0, 16)
    } finally {
        $sha.Dispose()
    }
}

# ---- baseline ----------------------------------------------------------------
function Invoke-BaselineAdd {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path $Path -PathType Leaf)) {
        Write-Host "usage: guardian.ps1 baseline add <file>"
        exit 64
    }
    Initialize-GuardianDirs
    $full = (Resolve-Path $Path).Path
    $id = Get-PathId -Path $full
    $fp = Get-PathFingerprint -Path $full
    [System.IO.File]::WriteAllText((Join-Path $BaselineDir "$id.path"), $full)
    [System.IO.File]::WriteAllText((Join-Path $BaselineDir "$id.fp"), $fp)
    Write-GuardianLog "baseline registered: $full"
    Write-Host ("registered: {0} (fp={1}...)" -f $full, $fp.Substring(0, 12))
}

function Invoke-BaselineList {
    Initialize-GuardianDirs
    Get-ChildItem -Path $BaselineDir -Filter "*.path" -ErrorAction SilentlyContinue | ForEach-Object {
        $path = [System.IO.File]::ReadAllText($_.FullName)
        $fp = [System.IO.File]::ReadAllText($_.FullName -replace '\.path$', '.fp')
        Write-Host "path=$path fp=$fp"
    }
}

# ---- patrol (baseline check, read-only) ---------------------------------------
function Invoke-Patrol {
    Initialize-GuardianDirs
    $round = 1
    $roundFile = Join-Path $StateDir "round"
    if (Test-Path $roundFile) { $round = ([int]([System.IO.File]::ReadAllText($roundFile))) + 1 }
    [System.IO.File]::WriteAllText($roundFile, [string]$round)

    $ts = Get-NowIso
    $findings = New-Object System.Collections.Generic.List[string]
    $level = "info"

    Get-ChildItem -Path $BaselineDir -Filter "*.path" -ErrorAction SilentlyContinue | ForEach-Object {
        $path = [System.IO.File]::ReadAllText($_.FullName)
        $fpFile = $_.FullName -replace '\.path$', '.fp'
        $fp = [System.IO.File]::ReadAllText($fpFile)
        if (-not (Test-Path $path -PathType Leaf)) {
            $level = "fault"
            $findings.Add("<li>MISSING: $path (file removed since deploy)</li>")
            return
        }
        $nowFp = Get-PathFingerprint -Path $path
        if ($nowFp -ne $fp) {
            if ($level -ne "fault") { $level = "warn" }
            $findings.Add("<li>DRIFT: $path (sha256 $($fp.Substring(0,12))... -> $($nowFp.Substring(0,12))...)</li>")
        }
    }

    if ($findings.Count -eq 0) { $findings.Add("<li>OK: all registered baselines match</li>") }

    $report = @{
        round    = $round
        ts       = $ts
        level    = $level
        findings = ($findings -join "")
    } | ConvertTo-Json -Compress

    $reportFile = Join-Path $ReportsDir ("round-{0:D6}.json" -f $round)
    [System.IO.File]::WriteAllText($reportFile, $report)
    Write-GuardianLog "patrol round=$round level=$level"
    Send-GuardianWebhook -PayloadJson $report
    if ($level -eq "fault") {
        Send-GuardianWebhook -PayloadJson (@{
            level = "fault"; msg = "fault detected in round $round"
        } | ConvertTo-Json -Compress)
    }
    Invoke-RenderPage
}

# ---- heartbeat ---------------------------------------------------------------
function Invoke-HeartbeatRun {
    Initialize-GuardianDirs
    $hostFp = [System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash(
            [System.Text.Encoding]::UTF8.GetBytes($env:COMPUTERNAME))
    ).Replace("-", "").ToLower().Substring(0, 16)
    $payload = @{
        type    = "heartbeat"
        ts      = Get-NowIso
        version = $Version
        host_fp = $hostFp
    } | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText((Join-Path $StateDir "last-heartbeat.json"), $payload)
    Write-GuardianLog "heartbeat sent (outbound only)"
    Send-GuardianWebhook -PayloadJson $payload
}

function Get-TaskCommand {
    return "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$GuardianHome\guardian.ps1`" heartbeat cron"
}

function Invoke-HeartbeatStart {
    Initialize-GuardianDirs
    # self-install: copy the adapter into GUARDIAN_HOME so the task is self-contained
    $self = $PSCommandPath
    if ($self -and ((Resolve-Path $self).Path -ne (Join-Path $GuardianHome "guardian.ps1"))) {
        Copy-Item -Path $self -Destination (Join-Path $GuardianHome "guardian.ps1") -Force
    }
    # idempotent: replace any existing task, then (re)create
    schtasks /Create /F /SC HOURLY /TN $TaskName /TR (Get-TaskCommand) | Out-Null
    Write-GuardianLog "heartbeat schtasks installed (interval: hourly)"
    Write-Host "heartbeat started (hourly, outbound-only)"
}

function Invoke-HeartbeatStop {
    schtasks /Delete /TN $TaskName /F 2>$null | Out-Null
    Write-GuardianLog "heartbeat schtasks removed"
    Write-Host "heartbeat stopped"
}

function Invoke-HeartbeatCron {
    # invoked by schtasks: one heartbeat ping + one patrol round
    Invoke-HeartbeatRun
    Invoke-Patrol
}

# ---- static receipt page -------------------------------------------------------
function Invoke-RenderPage {
    Initialize-GuardianDirs
    $out = Join-Path $PageDir "receipt.html"
    $maxPages = 50
    if ($env:GUARDIAN_MAX_PAGES) { $maxPages = [int]$env:GUARDIAN_MAX_PAGES }
    $rows = ""
    $reports = Get-ChildItem -Path $ReportsDir -Filter "round-*.json" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First $maxPages
    foreach ($f in $reports) {
        $d = $f | Get-Content -Raw | ConvertFrom-Json
        $rows += "<tr class=$($d.level)><td>$($d.round)</td><td>$($d.ts)</td><td>$($d.level.ToUpper())</td><td><ul>$($d.findings)</ul></td></tr>"
    }
    $html = @"
<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<title>Guardian Receipts</title>
<style>body{font-family:system-ui,sans-serif;margin:2rem}
table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:6px;text-align:left}
tr.fault{background:#ffe0e0}tr.warn{background:#fff3d0}tr.info{background:#e8ffe8}</style>
</head><body>
<h1>Guardian Receipts</h1>
<p>Last $maxPages patrol rounds. Levels: info / warn / fault.</p>
<table><tr><th>Round</th><th>Time</th><th>Level</th><th>Findings</th></tr>
$rows
</table></body></html>
"@
    [System.IO.File]::WriteAllText($out, $html)
    Write-Host "page updated: $out"
}

# ---- uninstall (one command, clean) ---------------------------------------------
function Invoke-Uninstall {
    schtasks /Delete /TN $TaskName /F 2>$null | Out-Null
    if (Test-Path $GuardianHome) {
        Remove-Item -Path $GuardianHome -Recurse -Force
        Write-Host "guardian uninstalled cleanly (scheduled task removed, no residue)"
    } else {
        Write-Host "guardian was not installed"
    }
}

# ---- entry --------------------------------------------------------------------
$Usage = @"
guardian.ps1 - post-deploy guardian v0, Windows native adapter (outbound-only, read-only)
  baseline add <file>        register baseline fingerprint for one file
  baseline list              list registered baselines
  patrol                     run one patrol round (read-only fingerprint check)
  heartbeat run|start|stop   one ping / install hourly schtasks / remove task
  heartbeat cron             invoked by schtasks (ping + patrol)
  page                       (re)render static receipt page
  uninstall                  remove task and all guardian files in one command
Env: GUARDIAN_HOME (default ~\.guardian), GUARDIAN_WEBHOOK_URL (optional;
     only fingerprints and levels are sent, never file contents)
"@

switch ($args[0]) {
    "baseline" {
        if ($args[1] -eq "add") { Invoke-BaselineAdd -Path $args[2] }
        elseif ($args[1] -eq "list") { Invoke-BaselineList }
        else { Write-Host "usage: guardian.ps1 baseline add <file> | list"; exit 64 }
    }
    "patrol" { Invoke-Patrol }
    "heartbeat" {
        switch ($args[1]) {
            "run" { Invoke-HeartbeatRun }
            "start" { Invoke-HeartbeatStart }
            "stop" { Invoke-HeartbeatStop }
            "cron" { Invoke-HeartbeatCron }
            default { Write-Host "usage: guardian.ps1 heartbeat run|start|stop|cron"; exit 64 }
        }
    }
    "page" { Invoke-RenderPage }
    "uninstall" { Invoke-Uninstall }
    "help" { Write-Host $Usage }
    default {
        if ($args.Count -eq 0) { Write-Host $Usage }
        else { Write-Host $Usage; exit 64 }
    }
}
