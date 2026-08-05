param(
    [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$referenceCli = Join-Path $PSScriptRoot "reference-library.ps1"
$initializer = Join-Path $PSScriptRoot "init-project.ps1"
$smokeRoot = Join-Path $root ("temp/smoke-reference-" + [guid]::NewGuid().ToString("N"))
$configDir = Join-Path $smokeRoot "config"
$libraryRoot = Join-Path $smokeRoot "library"
$fixtureRepo = Join-Path $smokeRoot "fixture-repo"
$projectPath = Join-Path $smokeRoot "project"
$oldConfigDir = $env:AWZ_CONFIG_DIR

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "Reference smoke assertion failed: $Message"
    }
}

function Invoke-Reference {
    param(
        [string[]]$Arguments,
        [int]$ExpectedExitCode = 0
    )
    $output = @(& $referenceCli @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    $actualExitCode = $LASTEXITCODE
    if ($actualExitCode -ne $ExpectedExitCode) {
        throw "Reference command exit $actualExitCode, expected ${ExpectedExitCode}: $($Arguments -join ' ')`n$($output -join "`n")"
    }
    return $output
}

try {
    $env:AWZ_CONFIG_DIR = $configDir
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $configDir "config.json") -Value '{invalid-json' -Encoding UTF8
    Invoke-Reference -Arguments @("list") -ExpectedExitCode 1 | Out-Null
    $missingRoot = Join-Path $smokeRoot "missing-library"
    @{ schemaVersion = 1; referenceRoot = $missingRoot } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $configDir "config.json") -Encoding UTF8
    Invoke-Reference -Arguments @("doctor") -ExpectedExitCode 1 | Out-Null
    Remove-Item -LiteralPath $configDir -Recurse -Force

    New-Item -ItemType Directory -Path $fixtureRepo -Force | Out-Null
    git -C $fixtureRepo init -b main | Out-Null
    git -C $fixtureRepo config user.name "AWZ Smoke"
    git -C $fixtureRepo config user.email "awz-smoke@example.invalid"
    Set-Content -LiteralPath (Join-Path $fixtureRepo "README.md") -Value "# Fixture Reference" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $fixtureRepo "LICENSE") -Value "MIT fixture" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $fixtureRepo "package.json") -Value '{"name":"fixture-reference","version":"1.2.3"}' -Encoding UTF8
    git -C $fixtureRepo add README.md LICENSE package.json
    git -C $fixtureRepo commit -m "fixture" | Out-Null

    Invoke-Reference -Arguments @("configure", "--root", $libraryRoot, "--dry-run") | Out-Null
    Assert-True (-not (Test-Path -LiteralPath $configDir)) "configure dry-run wrote config"
    Assert-True (-not (Test-Path -LiteralPath $libraryRoot)) "configure dry-run created library root"

    Invoke-Reference -Arguments @("configure", "--root", $libraryRoot) | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $configDir "config.json")) "configure did not write config"
    $configurePlanOutput = Invoke-Reference -Arguments @("configure", "--root", $libraryRoot, "--dry-run", "--json")
    $configurePlan = (($configurePlanOutput -join "`n") | ConvertFrom-Json)
    Assert-True ($configurePlan.operation -eq "reference.configure") "configure JSON operation is invalid"
    Assert-True ([bool]$configurePlan.plan.planHash) "configure JSON plan hash is missing"
    Invoke-Reference -Arguments @("configure", "--root", $libraryRoot, "--json", "--plan-hash", $configurePlan.plan.planHash) | Out-Null
    $writtenConfig = Get-Content -LiteralPath (Join-Path $configDir "config.json") -Raw | ConvertFrom-Json
    Assert-True ($writtenConfig.schemaVersion -eq 2) "configure did not write schema v2"
    Invoke-Reference -Arguments @("configure", "--root", $libraryRoot, "--json") -ExpectedExitCode 1 | Out-Null
    foreach ($directory in @("catalog", "repos", "context-cache", "logs")) {
        Assert-True (Test-Path -LiteralPath (Join-Path $libraryRoot $directory)) "missing library directory: $directory"
    }

    Invoke-Reference -Arguments @(
        "add", "--id", "fixture", "--name", "Fixture Reference", "--url", $fixtureRepo,
        "--category", "frontend", "--tag", "frontend,animation", "--read-first", "README.md",
        "--use-when", "需要 smoke reference", "--canonical-url", "https://example.com/fixture.git", "--allow-local", "--dry-run"
    ) | Out-Null
    $referenceRepo = Join-Path $libraryRoot "repos/frontend/fixture"
    Assert-True (-not (Test-Path -LiteralPath $referenceRepo)) "add dry-run cloned repository"
    Invoke-Reference -Arguments @("add", "--id", "local-without-allow", "--url", $fixtureRepo, "--dry-run") -ExpectedExitCode 1 | Out-Null
    $credentialOutput = Invoke-Reference -Arguments @("add", "--id", "credential-url", "--url", "https://user:secret@example.com/repo.git", "--dry-run") -ExpectedExitCode 1
    Assert-True (-not (($credentialOutput -join "`n").Contains("secret"))) "credential-bearing URL leaked in output"
    Invoke-Reference -Arguments @("add", "--id", "escape", "--url", $fixtureRepo, "--category", "../escape", "--allow-local", "--dry-run") -ExpectedExitCode 1 | Out-Null

    Invoke-Reference -Arguments @(
        "add", "--id", "fixture", "--name", "Fixture Reference", "--url", $fixtureRepo,
        "--category", "frontend", "--tag", "frontend,animation", "--read-first", "README.md",
        "--use-when", "需要 smoke reference", "--canonical-url", "https://example.com/fixture.git", "--allow-local"
    ) | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $referenceRepo ".git")) "reference repository was not cloned"
    Assert-True (Test-Path -LiteralPath (Join-Path $libraryRoot "catalog/fixture.json")) "catalog was not written"

    $listOutput = Invoke-Reference -Arguments @("list")
    Assert-True (($listOutput -join "`n") -match "fixture") "list did not show fixture"
    $showOutput = Invoke-Reference -Arguments @("show", "--id", "fixture")
    Assert-True (($showOutput -join "`n") -match '"version": "1.2.3"') "show did not detect version"

    & $initializer -TargetPath $projectPath -ProjectName "Reference Smoke Project" | Out-Null
    $mappingPath = Join-Path $projectPath ".awz/references.json"
    Assert-True (Test-Path -LiteralPath $mappingPath) "initializer did not create project mapping"

    Invoke-Reference -Arguments @("map", "--project", $projectPath, "--id", "fixture", "--purpose", "smoke", "--dry-run") | Out-Null
    Assert-True (-not ((Get-Content -LiteralPath $mappingPath -Raw).Contains("fixture"))) "map dry-run changed mapping"
    Invoke-Reference -Arguments @("map", "--project", $projectPath, "--id", "fixture", "--purpose", "smoke") | Out-Null

    Invoke-Reference -Arguments @("context", "--project", $projectPath, "--dry-run") | Out-Null
    $contextPath = Join-Path $projectPath "docs/agent-room/reference-context.md"
    Assert-True (-not (Test-Path -LiteralPath $contextPath)) "context dry-run wrote output"
    Invoke-Reference -Arguments @("context", "--project", $projectPath) | Out-Null
    Assert-True ((Get-Content -LiteralPath $contextPath -Raw).Contains("Fixture Reference")) "context did not include mapped reference"

    Invoke-Reference -Arguments @("status", "--project", $projectPath) | Out-Null
    Invoke-Reference -Arguments @("doctor", "--project", $projectPath) | Out-Null

    Add-Content -LiteralPath (Join-Path $referenceRepo "README.md") -Value "dirty"
    $doctorOutput = Invoke-Reference -Arguments @("doctor", "--project", $projectPath) -ExpectedExitCode 1
    Assert-True (($doctorOutput -join "`n") -match "dirty") "doctor did not report dirty reference"

    Invoke-Reference -Arguments @("unmap", "--project", $projectPath, "--id", "fixture") | Out-Null
    Assert-True (Test-Path -LiteralPath $referenceRepo) "unmap deleted the global clone"
    Write-Host "Reference Library smoke passed: $smokeRoot"
}
finally {
    if ($null -eq $oldConfigDir) {
        Remove-Item Env:AWZ_CONFIG_DIR -ErrorAction SilentlyContinue
    }
    else {
        $env:AWZ_CONFIG_DIR = $oldConfigDir
    }
    if ((-not $KeepArtifacts) -and (Test-Path -LiteralPath $smokeRoot)) {
        Remove-Item -LiteralPath $smokeRoot -Recurse -Force
    }
}
