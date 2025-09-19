Param(
  [string]$MetaEditor = "C:\Users\kwaku\AppData\Roaming\MetaTrader 5 EXNESS\MetaEditor64.exe",
  [string]$IncludeDir = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$SrcFolders = @(
  Join-Path $RepoRoot "MQL5\Experts",
  Join-Path $RepoRoot "MQL5\Indicators"
)
$LogsDir = Join-Path $RepoRoot "tools\build-logs"
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

if (-not (Test-Path $MetaEditor)) {
  Write-Error "MetaEditor not found at: $MetaEditor"
  exit 1
}

$Targets = Get-ChildItem -Path $SrcFolders -Filter *.mq5 -Recurse -ErrorAction SilentlyContinue
if (-not $Targets) {
  Write-Host "No .mq5 files found under MQL5\Experts or MQL5\Indicators."
  exit 0
}

$compileErrors = 0
$compileWarnings = 0

foreach ($f in $Targets) {
  $rel = $f.FullName.Substring($RepoRoot.Path.Length + 1)
  $logFile = Join-Path $LogsDir ($rel.Replace('\','_') + ".log")

  Write-Host "Compiling $rel"
  $args = @("/compile:$($f.FullName)", "/log:$logFile")
  if ($IncludeDir) { $args += "/include:$IncludeDir" }

  & $MetaEditor @args | Out-Null

  if (Test-Path $logFile) {
    $text = Get-Content $logFile -Raw
    $errCount  = ([regex]::Matches($text, "(?i)\berror\b")).Count
    $warnCount = ([regex]::Matches($text, "(?i)\bwarning\b")).Count

    if ($errCount -gt 0) {
      $compileErrors += $errCount
      Write-Host "  -> Errors: $errCount  (see: $((Resolve-Path $logFile).Path))"
    } elseif ($warnCount -gt 0) {
      $compileWarnings += $warnCount
      Write-Host "  -> Warnings: $warnCount (see: $((Resolve-Path $logFile).Path))"
    } else {
      Write-Host "  -> OK"
    }
  } else {
    Write-Warning "No log produced for $rel"
  }
}

Write-Host "`nSummary: errors=$compileErrors, warnings=$compileWarnings, logs at $LogsDir"
if ($compileErrors -gt 0) { exit 1 } else { exit 0 }
