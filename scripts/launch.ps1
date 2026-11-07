$ErrorActionPreference = 'Stop'
$studioRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $studioRoot
try {
  $response = Invoke-WebRequest -Uri 'http://127.0.0.1:5173/' -UseBasicParsing -TimeoutSec 2
  if ($response.Content -notmatch 'My Game Studio') { throw 'Порт 5173 занят другим приложением.' }
  Start-Process 'http://127.0.0.1:5173/'
  exit 0
} catch {
  if ($_.Exception.Message -match 'занят') { Write-Error $_; exit 1 }
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Error 'Установите Node.js 22.12 или новее.'; exit 1 }
if (-not (Test-Path -LiteralPath (Join-Path $studioRoot 'node_modules'))) {
  & npm.cmd ci
  if ($LASTEXITCODE -ne 0) { Write-Error 'Не удалось установить зависимости. Проверьте интернет.'; exit 1 }
}
$runtimeDirectory = Join-Path $studioRoot 'work'
New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
$viteEntry = Join-Path $studioRoot 'node_modules\vite\bin\vite.js'
$server = Start-Process -FilePath (Get-Command node).Source -ArgumentList @(('"' + $viteEntry + '"'),'--host','127.0.0.1','--port','5173','--strictPort') -WorkingDirectory $studioRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtimeDirectory 'server.log') -RedirectStandardError (Join-Path $runtimeDirectory 'server-error.log')
for ($attempt = 0; $attempt -lt 30; $attempt++) {
  Start-Sleep -Milliseconds 300
  if ($server.HasExited) { Write-Error 'Сервер не запустился. Смотрите work/server-error.log'; exit 1 }
  try {
    $response = Invoke-WebRequest -Uri 'http://127.0.0.1:5173/' -UseBasicParsing -TimeoutSec 1
    if ($response.StatusCode -eq 200 -and $response.Content -match 'My Game Studio') {
      Start-Process 'http://127.0.0.1:5173/'
      Write-Host 'Студия открыта. Данные сохраняются в вашем браузере.'
      exit 0
    }
  } catch { }
}
Write-Error 'Не удалось дождаться локального сайта. Смотрите work/server-error.log'
exit 1
