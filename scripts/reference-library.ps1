$ErrorActionPreference = "Stop"
$core = Join-Path $PSScriptRoot "reference-library.py"

if (-not (Test-Path -LiteralPath $core -PathType Leaf)) {
    throw "Reference Library core not found: $core"
}

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    & $python.Source $core @args
    exit $LASTEXITCODE
}

$pythonLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($pythonLauncher) {
    & $pythonLauncher.Source -3 $core @args
    exit $LASTEXITCODE
}

throw "Python 3 is required for the optional Reference Library commands."
