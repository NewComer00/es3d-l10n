$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path

$ToolsDir = Join-Path $ProjectRoot 'tools\uv'
$Uv = Join-Path $ToolsDir 'uv.exe'
if (-not (Test-Path $Uv)) {
    $env:UV_UNMANAGED_INSTALL = $ToolsDir
    irm https://astral.sh/uv/install.ps1 | iex
    if (-not (Test-Path $Uv)) {
        throw "uv install finished but $Uv was not found"
    }
}

Push-Location $ProjectRoot
try {
    & $Uv python install
    if ($LASTEXITCODE -ne 0) { throw "uv python install failed with exit code $LASTEXITCODE" }

    if (Test-Path 'pyproject.toml') {
        & $Uv sync --locked
        if ($LASTEXITCODE -ne 0) { throw "uv sync failed with exit code $LASTEXITCODE" }
    }
} finally {
    Pop-Location
}

$ActivateScript = Join-Path $ProjectRoot '.venv\Scripts\Activate.ps1'
if (-not (Test-Path -LiteralPath $ActivateScript)) {
    throw "venv not found: $ActivateScript"
}

Write-Host 'bootstrap: ok' -ForegroundColor Green

if ($MyInvocation.InvocationName -eq '.') {
    . $ActivateScript
    Write-Host "bootstrap: venv activated ($ProjectRoot\.venv)" -ForegroundColor Green
} else {
    Write-Host ''
    Write-Host 'bootstrap: activate for this shell:' -ForegroundColor Yellow
    Write-Host "  . '$ActivateScript'"
    Write-Host 'Or dot-source bootstrap so activation persists:' -ForegroundColor DarkGray
    Write-Host '  . .\bootstrap.ps1'
}
