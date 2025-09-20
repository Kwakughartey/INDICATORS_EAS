Param(
  [string]$MetaEditor = "C:\Users\kwaku\AppData\Roaming\MetaTrader 5 EXNESS\MetaEditor64.exe",
  [string]$IncludeDir = ""
)
# Fallback to a system-wide MetaEditor if the user-profile path isn't visible (e.g., service account)
if (-not (Test-Path $MetaEditor)) {
  $pf = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
  if (Test-Path $pf) { $MetaEditor = $pf }
}


$ErrorActionPreference = "Stop"

# Make RepoRoot a STRING, not a PathInfo/array
$RepoRoot = (Split-Path -Parent $PSScriptRoot)

$SrcFolders = @(
  (Join-Path -Path $RepoRoot -ChildPath "MQL5\Experts"),
  (Join-Path -Path $RepoRoot -ChildPath "MQL5\Indicators")
)

$LogsDir = Join-Path -Path $RepoRoot -ChildPath "tools\build-logs"
New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null

if (-not (Test-Path $MetaEditor)) {
  Write-Error "MetaEditor not found at: $MetaEditor"
  exit 1
}

# Find all .mq5 sources in Experts/Indicators
$Targets = Get-ChildItem -Path $SrcFolders -Filter *.mq5 -Recurse -ErrorAction SilentlyContinue
if (-not $Targets) {
  Write-Host "No .mq5 files found under MQL5\Experts or MQL5\Indicators."
  exit 0
}

$compileErrors = 0
$compileWarnings = 0

foreach ($f in $Targets) {
  # Compute a nice relative path for logs
  $full = (Resolve-Path $f.FullName).Path
  $rel  = $full.Substring($RepoRoot.Length + 1)
  $logFile = Join-Path -Path $LogsDir -ChildPath ($rel.Replace('\','_') + ".log")

  Write-Host "Compiling $rel"
  $args = @("/compile:`"$full`"", "/log:`"$logFile`"")
  if ($IncludeDir) { $args += "/include:`"$IncludeDir`"" }

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
