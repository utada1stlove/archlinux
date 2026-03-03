$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetDir = Join-Path $env:USERPROFILE ".vscode\extensions\dae-local-syntax"

Write-Host "Installing DAE syntax extension..."
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
Copy-Item -Path (Join-Path $scriptDir "*") -Destination $targetDir -Recurse -Force

Write-Host "Installed to: $targetDir"
Write-Host "Now run in VS Code: Developer: Reload Window"
