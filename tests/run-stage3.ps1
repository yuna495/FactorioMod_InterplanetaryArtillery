param(
  [string]$Factorio = 'D:\Games\steam\steamapps\common\Factorio\bin\x64\Factorio.exe',
  [switch]$SpaceAge,
  [ValidateSet(3, 4)][int]$Stage = 3
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$run = Join-Path $repo (".codex-test-output/stage$Stage-" + [guid]::NewGuid().ToString('N'))
$mods = Join-Path $run 'mods'
$mod = Join-Path $mods 'InterplanetaryArtillery'
New-Item -ItemType Directory -Path $mod -Force | Out-Null
foreach ($directory in @('saves', 'script-output', 'temp', 'scenarios', 'campaigns', 'archive', 'config')) {
  New-Item -ItemType Directory -Path (Join-Path $run $directory) -Force | Out-Null
}
foreach ($file in @('info.json', 'data.lua', 'control.lua', 'scripts', 'locale', 'tests')) {
  Copy-Item -LiteralPath (Join-Path $repo $file) -Destination $mod -Recurse
}
Move-Item -LiteralPath (Join-Path $mod 'control.lua') -Destination (Join-Path $mod 'production-control.lua')
$bootstrap = if ($Stage -eq 4) { 'bootstrap-stage4.lua' } else { 'bootstrap.lua' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot $bootstrap) -Destination (Join-Path $mod 'control.lua')
$data = Join-Path (Split-Path (Split-Path (Split-Path $Factorio -Parent) -Parent) -Parent) 'data'
$config = Join-Path $run 'config.ini'
function Invoke-TestFactorio([string[]]$Arguments, [string]$LogPath) {
  $currentLog = Join-Path $run 'factorio-current.log'
  if (Test-Path -LiteralPath $currentLog) { Remove-Item -LiteralPath $currentLog }
  $quoted = $Arguments | ForEach-Object { '"' + $_ + '"' }
  $process = Start-Process -FilePath $Factorio -ArgumentList $quoted -WindowStyle Hidden -PassThru
  $deadline = (Get-Date).AddSeconds(120)
  $passed = $false
  try {
    while (-not $process.HasExited) {
      if ((Get-Date) -gt $deadline) { throw "Factorio timed out: $LogPath" }
      if ((Test-Path -LiteralPath $currentLog) -and
        (Select-String -LiteralPath $currentLog -Pattern "STAGE$Stage ALL PASSED" -Quiet)) {
        $passed = $true
        Stop-Process -Id $process.Id
        break
      }
      if ((Test-Path -LiteralPath $currentLog) -and
        (Select-String -LiteralPath $currentLog -Pattern 'Exception at tick|Hosting multiplayer game failed' -Quiet)) {
        throw "Factorio test error: $currentLog"
      }
      Start-Sleep -Milliseconds 500
      $process.Refresh()
    }
    $process.WaitForExit()
    Copy-Item -LiteralPath (Join-Path $run 'factorio-current.log') -Destination $LogPath
    if (-not $passed -and $process.ExitCode -ne 0) { throw "Factorio exited with $($process.ExitCode): $LogPath" }
  } finally {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id }
  }
}
@('[path]', ('read-data=' + $data.Replace('\', '/')), ('write-data=' + $run.Replace('\', '/'))) | Set-Content -LiteralPath $config -Encoding UTF8
@{mods = @(
  @{name = 'base'; enabled = $true}, @{name = 'InterplanetaryArtillery'; enabled = $true},
  @{name = 'space-age'; enabled = [bool]$SpaceAge}, @{name = 'quality'; enabled = [bool]$SpaceAge},
  @{name = 'elevated-rails'; enabled = [bool]$SpaceAge}
)} |
  ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $mods 'mod-list.json') -Encoding UTF8
$save = Join-Path $run 'initial.zip'
Invoke-TestFactorio -Arguments @('--config', $config, '--mod-directory', $mods, '--create', $save) -LogPath (Join-Path $run 'create.log')
Copy-Item -LiteralPath $save -Destination (Join-Path $run "saves/stage$Stage-flight.zip")
$settings = Join-Path $run 'server-settings.json'
$serverSettings = Get-Content -LiteralPath (Join-Path $data 'server-settings.example.json') -Raw | ConvertFrom-Json
$overrides = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'server-settings.json') -Raw | ConvertFrom-Json
foreach ($property in $overrides.PSObject.Properties) { $serverSettings.($property.Name) = $property.Value }
$serverSettings | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $settings -Encoding UTF8
foreach ($phase in @('initial', 'reload')) {
  $log = Join-Path $run ($phase + '.log')
  if ($phase -eq 'reload') { $save = Join-Path $run "saves/stage$Stage-flight.zip" }
  Invoke-TestFactorio -Arguments @('--config', $config, '--mod-directory', $mods, '--start-server', $save, '--server-settings', $settings, '--bind', '127.0.0.1:34987', '--until-tick', '4000') -LogPath $log
  if (-not (Select-String -LiteralPath $log -Pattern "STAGE$Stage ALL PASSED" -Quiet)) {
    throw "Stage $phase failed: $log"
  }
  if ($phase -eq 'reload' -and -not (Select-String -LiteralPath $log -Pattern "STAGE$Stage RELOAD CONFIRMED" -Quiet)) {
    throw "Reload state was not verified: $log"
  }
  Select-String -LiteralPath $log -Pattern "STAGE$Stage (PASS|ALL|RELOAD|IN-FLIGHT)" | ForEach-Object { $_.Line }
}
Write-Output "Test artifacts: $run"
