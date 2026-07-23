[CmdletBinding()]
param(
  [string] $SpecPath = (Join-Path $PSScriptRoot '..\..\..\kelivo-api\openapi\generated\openapi.json'),
  [string] $ProxyUrl = 'http://127.0.0.1:7890',
  [string] $TempPath = (Join-Path $PSScriptRoot '..\..\.dart_tool\tmp'),
  [string] $DartExecutable = 'dart'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-SingleIntegerEnums {
  param([Parameter(Mandatory)] [object] $Node)

  if ($Node -is [Collections.IDictionary]) {
    if (
      ($Node['type'] -eq 'integer' -or $Node['type'] -eq 'number') -and
      $Node.Contains('enum')
    ) {
      $values = @($Node['enum'])
      if (
        $values.Count -eq 1 -and
        (
          $values[0] -is [int] -or
          $values[0] -is [long] -or
          $values[0] -is [double] -or
          $values[0] -is [decimal]
        )
      ) {
        $literal = $values[0]
        if ([Math]::Truncate([double] $literal) -eq [double] $literal) {
          $Node['type'] = 'integer'
        }
        $Node.Remove('enum')
        $Node['minimum'] = $literal
        $Node['maximum'] = $literal
      }
    }
    foreach ($value in @($Node.Values)) {
      Convert-SingleIntegerEnums -Node $value
    }
    return
  }

  if ($Node -is [Collections.IEnumerable] -and $Node -isnot [string]) {
    foreach ($value in $Node) {
      Convert-SingleIntegerEnums -Node $value
    }
  }
}

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

# OpenAPI Generator 会把整数单值 enum 生成为字符串 EnumClass；等价收紧为相同
# minimum/maximum，确保线上的 JSON 仍发送数字且生成文件无需二次修改。
$generatorSpec = Join-Path $TempPath 'kelivo-openapi-generator-input.json'
$specDocument = Get-Content -Raw -LiteralPath $resolvedSpec |
  ConvertFrom-Json -AsHashtable -Depth 100
Convert-SingleIntegerEnums -Node $specDocument
$specDocument |
  ConvertTo-Json -Depth 100 |
  Set-Content -LiteralPath $generatorSpec -Encoding utf8NoBOM

$generatorArgs = @(
  '--yes',
  '@openapitools/openapi-generator-cli@2.25.2',
  'generate',
  '-g',
  'dart-dio',
  '-i',
  $generatorSpec,
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
