[CmdletBinding()]
param(
  [string] $SpecPath = (Join-Path $PSScriptRoot '..\..\..\kelivo-api\openapi\generated\openapi.json'),
  [string] $ProxyUrl = 'http://127.0.0.1:7890',
  [string] $TempPath = 'D:\Temp',
  [string] $DartExecutable = 'dart'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$resolvedSpec = (Resolve-Path $SpecPath).Path
$outputPath = Join-Path $repoRoot 'dependencies\kelivo_sync_api_client'
$repoPrefix = $repoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar

if (Test-Path -LiteralPath $outputPath) {
  $resolvedOutput = (Resolve-Path $outputPath).Path
  if (-not $resolvedOutput.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "生成目录不在仓库内：$resolvedOutput"
  }
  Remove-Item -LiteralPath $resolvedOutput -Recurse -Force
}

New-Item -ItemType Directory -Path $TempPath -Force | Out-Null
$env:HTTP_PROXY = $ProxyUrl
$env:HTTPS_PROXY = $ProxyUrl
$env:TEMP = $TempPath
$env:TMP = $TempPath

$generatorArgs = @(
  '--yes',
  '@openapitools/openapi-generator-cli@2.25.2',
  'generate',
  '-g',
  'dart-dio',
  '-i',
  $resolvedSpec,
  '-o',
  $outputPath,
  '-t',
  (Join-Path $PSScriptRoot 'templates'),
  '--global-property',
  'apiDocs=false,modelDocs=false,apiTests=false,modelTests=false',
  '--additional-properties',
  'pubName=kelivo_sync_api_client,pubVersion=0.1.0,pubDescription=Kelivo同步服务Dio客户端,serializationLibrary=built_value,legacyDiscriminatorBehavior=false'
)

Push-Location $PSScriptRoot
try {
  & npx.cmd @generatorArgs
  if ($LASTEXITCODE -ne 0) {
    throw "客户端生成失败：$LASTEXITCODE"
  }
} finally {
  Pop-Location
}

$unwantedPaths = @('README.md', 'doc', 'test', 'bin', '.openapi-generator', '.openapi-generator-ignore')
foreach ($relativePath in $unwantedPaths) {
  $target = Join-Path $outputPath $relativePath
  if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
  }
}

Push-Location $outputPath
try {
  & $DartExecutable pub get
  if ($LASTEXITCODE -ne 0) {
    throw "生成包依赖解析失败：$LASTEXITCODE"
  }
  & $DartExecutable run build_runner build
  if ($LASTEXITCODE -ne 0) {
    throw "生成包代码生成失败：$LASTEXITCODE"
  }
  & $DartExecutable format lib
  if ($LASTEXITCODE -ne 0) {
    throw "生成包格式化失败：$LASTEXITCODE"
  }
  & $DartExecutable analyze
  if ($LASTEXITCODE -ne 0) {
    throw "生成包静态分析失败：$LASTEXITCODE"
  }
} finally {
  Pop-Location
}
