param(
    [string]$PackageRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$TestArguments = @()
)

$ErrorActionPreference = 'Stop'
$resolvedPackageRoot = (Resolve-Path -LiteralPath $PackageRoot).Path
$pubspec = Join-Path $resolvedPackageRoot 'pubspec.yaml'
if (-not (Test-Path -LiteralPath $pubspec -PathType Leaf)) {
    throw "测试包缺少 pubspec.yaml：$resolvedPackageRoot"
}

$dartTool = Join-Path $resolvedPackageRoot '.dart_tool'
$marker = Join-Path $dartTool 'kelivo_secure_core_test_store.marker'
if (Test-Path -LiteralPath $marker) {
    throw "测试存储标记已存在，请先确认没有其他安全核心测试在运行：$marker"
}

$flutter = (Get-Command 'flutter' -ErrorAction Stop).Source
$exitCode = 1
try {
    New-Item -ItemType Directory -Path $dartTool -Force | Out-Null
    [IO.File]::WriteAllText(
        $marker,
        'kelivo-secure-core-test-store-v1',
        [Text.UTF8Encoding]::new($false)
    )
    Push-Location -LiteralPath $resolvedPackageRoot
    try {
        $arguments = @(
            'test'
            '--dart-define=KELIVO_SECURE_CORE_TEST_STORE=true'
        ) + $TestArguments
        & $flutter @arguments
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}
finally {
    if (Test-Path -LiteralPath $marker) {
        Remove-Item -LiteralPath $marker -Force
    }
}

exit $exitCode
