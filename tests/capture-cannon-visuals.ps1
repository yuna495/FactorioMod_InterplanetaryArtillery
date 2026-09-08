param([Parameter(Mandatory=$true)][string]$Run,
  [string]$Factorio='D:\Games\steam\steamapps\common\Factorio\bin\x64\factorio.exe')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$runPath=(Resolve-Path -LiteralPath $Run).Path
if (-not $runPath.StartsWith((Join-Path $repo '.codex-test-output')+[IO.Path]::DirectorySeparatorChar)) { throw 'Use an isolated test run within this repository.' }
$mod=Join-Path $runPath 'mods/InterplanetaryArtillery'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'cannon-visuals-screenshots.lua') -Destination (Join-Path $mod 'tests/cannon-visuals-screenshots.lua')
@('require("production-control")','require("tests.cannon-visuals-screenshots")') | Set-Content -LiteralPath (Join-Path $mod 'control.lua') -Encoding utf8
$info=Get-Content -LiteralPath (Join-Path $mod 'info.json') -Raw | ConvertFrom-Json
$info.version='1.0.1'
$info | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $mod 'info.json') -Encoding utf8
$arguments=@('--config',(Join-Path $runPath 'config.ini'),'--mod-directory',(Join-Path $runPath 'mods'),
  '--load-game',(Join-Path $runPath 'saves/stage8-flight.zip'),'--disable-audio')
$quoted=$arguments | ForEach-Object { '"'+$_+'"' }
$gameDirectory=Split-Path (Split-Path (Split-Path $Factorio -Parent) -Parent) -Parent
$process=Start-Process -FilePath $Factorio -ArgumentList $quoted -WorkingDirectory $gameDirectory -WindowStyle Hidden -PassThru
$deadline=(Get-Date).AddSeconds(180)
$logPath=Join-Path $runPath 'factorio-current.log'
try {
  while (-not $process.HasExited) {
    if ((Get-Date) -gt $deadline) { throw 'Screenshot client timed out.' }
    if ((Test-Path -LiteralPath $logPath) -and (Select-String -LiteralPath $logPath -Pattern 'MONOLITH SCREENSHOTS COMPLETE' -Quiet)) {
      Start-Sleep -Seconds 2
      $destination=Join-Path $repo 'art/review_ingame'
      New-Item -ItemType Directory -Path $destination -Force | Out-Null
      Copy-Item -Path (Join-Path $runPath 'script-output/monolith-review/*.png') -Destination $destination
      Write-Output "Screenshots: $destination"
      return
    }
    Start-Sleep -Milliseconds 500
    $process.Refresh()
  }
  throw "Screenshot client exited: $($process.ExitCode). See $logPath"
} finally {
  if (-not $process.HasExited) { Stop-Process -Id $process.Id }
}
