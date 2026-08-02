param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$resolvedRepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$packageRoot = Join-Path $resolvedRepositoryRoot 'dependencies/kelivo_secure_core'
$config = Join-Path $packageRoot 'ffigen.yaml'
$binding = Join-Path $packageRoot 'lib/kelivo_secure_core_bindings_generated.dart'

foreach ($requiredFile in @($config, $binding)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "安全核心 FFI 门禁缺少文件：$requiredFile"
    }
}

$flutter = (Get-Command 'flutter' -ErrorAction Stop).Source
$dart = (Get-Command 'dart' -ErrorAction Stop).Source
$git = (Get-Command 'git' -ErrorAction Stop).Source
$bindingRelativePath = [IO.Path]::GetRelativePath(
    $resolvedRepositoryRoot,
    $binding
).Replace('\', '/')

function Assert-BindingClean([string]$stage) {
    & $git -C $resolvedRepositoryRoot diff --quiet HEAD -- $bindingRelativePath
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        return
    }
    if ($exitCode -eq 1) {
        throw "安全核心 FFI 绑定在${stage}存在未提交差异：$bindingRelativePath"
    }
    throw "检查安全核心 FFI 绑定失败，Git 退出码：$exitCode"
}

Assert-BindingClean '生成前'

Push-Location -LiteralPath $packageRoot
try {
    & $flutter 'pub' 'get'
    if ($LASTEXITCODE -ne 0) {
        throw "安全核心 Flutter 依赖解析失败，退出码：$LASTEXITCODE"
    }

    & $dart 'run' 'ffigen' '--config' 'ffigen.yaml'
    if ($LASTEXITCODE -ne 0) {
        throw "安全核心 FFI 生成失败，退出码：$LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Assert-BindingClean '重新生成后'
Write-Host '安全核心 FFI 绑定与 C ABI 一致。'
