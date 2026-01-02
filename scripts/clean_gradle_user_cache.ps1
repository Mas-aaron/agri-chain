$ErrorActionPreference = 'Stop'
Write-Host "Stopping Gradle daemons..."
Push-Location "$PSScriptRoot\..\android"
try { ./gradlew --stop | Out-Host } catch {}
Pop-Location

$paths = @(
  Join-Path $env:USERPROFILE ".gradle\caches\jars-9",
  Join-Path $env:USERPROFILE ".gradle\caches\transforms-3",
  Join-Path $env:USERPROFILE ".gradle\wrapper\dists\gradle-8.2.1",
  Join-Path $env:USERPROFILE ".gradle\wrapper\dists\gradle-8.2.1-all",
  Join-Path $env:USERPROFILE ".gradle\wrapper\dists\gradle-8.3",
  Join-Path $env:USERPROFILE ".gradle\wrapper\dists\gradle-8.3-all"
)

foreach ($p in $paths) {
  if (Test-Path $p) {
    Write-Host "Removing $p"
    Remove-Item -Recurse -Force $p
  } else {
    Write-Host "Skip missing $p"
  }
}

Write-Host "Project clean..."
Push-Location "$PSScriptRoot\.."
flutter clean | Out-Host
Write-Host "Pub get..."
flutter pub get | Out-Host
Pop-Location

Write-Host "Done cleaning Gradle user caches."
