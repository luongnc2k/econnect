param(
  [string]$Host = "0.0.0.0",
  [int]$Port = 8000,
  [switch]$NoReload
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$serverDir = Join-Path $repoRoot "server"
$pythonExe = Join-Path $serverDir "venv\Scripts\python.exe"

if (-not (Test-Path $pythonExe)) {
  throw "Khong tim thay $pythonExe. Hay tao venv cho backend truoc."
}

function Stop-StaleBackendProcesses {
  param(
    [string]$TargetDir
  )

  $escapedTargetDir = [Regex]::Escape($TargetDir)
  $targets = Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and
    $_.CommandLine -match $escapedTargetDir -and
    $_.CommandLine -match "uvicorn(\.exe)?" -and
    $_.CommandLine -match "main:app"
  }

  $ids = New-Object 'System.Collections.Generic.HashSet[int]'
  foreach ($target in $targets) {
    $null = $ids.Add([int]$target.ProcessId)

    $children = Get-CimInstance Win32_Process | Where-Object {
      $_.ParentProcessId -eq $target.ProcessId
    }
    foreach ($child in $children) {
      $null = $ids.Add([int]$child.ProcessId)
    }
  }

  foreach ($id in $ids) {
    Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
  }
}

Stop-StaleBackendProcesses -TargetDir $serverDir
Start-Sleep -Seconds 1

$arguments = @(
  "-m",
  "uvicorn",
  "main:app",
  "--host",
  $Host,
  "--port",
  $Port.ToString()
)

if (-not $NoReload) {
  $arguments += "--reload"
}

Push-Location $serverDir
try {
  Write-Host "Starting backend on http://$Host`:$Port ..."
  & $pythonExe @arguments
}
finally {
  Pop-Location
}
