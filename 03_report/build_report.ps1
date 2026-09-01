[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$CaseDir,
    [string]$AnalysisDir,
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
$CaseDir = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $CaseDir -ErrorAction Stop))
if (-not $AnalysisDir) { $AnalysisDir = Join-Path (Split-Path $CaseDir -Parent) ((Split-Path $CaseDir -Leaf) + '-analysis') }
if (-not $OutputDir) { $OutputDir = Join-Path (Split-Path $CaseDir -Parent) ((Split-Path $CaseDir -Leaf) + '-report') }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$metadataPath = Join-Path $CaseDir '00_meta\collection.json'
$metadata = if (Test-Path -LiteralPath $metadataPath) { Get-Content -Raw -LiteralPath $metadataPath | ConvertFrom-Json } else { $null }
$manifestPath = Join-Path $CaseDir '00_meta\sha256_manifest.csv'
$manifestCount = if (Test-Path -LiteralPath $manifestPath) { @(Import-Csv -LiteralPath $manifestPath).Count } else { 0 }
$verificationPath = Join-Path $AnalysisDir '00_meta\hash_verification.csv'
$verification = if (Test-Path -LiteralPath $verificationPath) { @(Import-Csv -LiteralPath $verificationPath) } else { @() }
$volatilityCount = if (Test-Path -LiteralPath (Join-Path $AnalysisDir 'volatility')) { @(Get-ChildItem -LiteralPath (Join-Path $AnalysisDir 'volatility') -File).Count } else { 0 }

$caseId = if ($metadata.CaseId) { $metadata.CaseId } else { Split-Path $CaseDir -Leaf }
$failureText = if ($metadata.Failures) { ($metadata.Failures -join "`n- ") } else { '无' }
$verificationSummary = if ($verification.Count -eq 0) { '未找到 ANA 验真结果' } else { "MATCH=$(@($verification | Where-Object Status -eq 'MATCH').Count); PROBLEM=$(@($verification | Where-Object Status -ne 'MATCH').Count)" }

$report = @"
# 事件响应报告：$caseId

> 状态：草稿。本文档由工具生成，必须由分析人员复核、补充并签字。

## 1. 案件信息

| 字段 | 内容 |
|---|---|
| 案件 ID | $caseId |
| 主机 | $($metadata.Hostname) |
| 操作者 | $($metadata.Operator) |
| 采集开始 | $($metadata.StartedAt) |
| 采集结束 | $($metadata.FinishedAt) |
| collection 产物数 | $manifestCount |
| ANA hash 验真 | $verificationSummary |
| Volatility 结果数 | $volatilityCount |

## 2. 执行摘要

### 已确认事实

- [填写：引用具体证据文件和 SHA256]

### 高置信度判断

- [填写：说明依据、时间范围和置信度]

### 待验证事项

- [填写：负责人、验证动作和截止时间]

## 3. 时间线

详见 `timeline.csv`。每一行应包含时间、主机/账户、事件、证据路径和置信度。

## 4. IOC 与处置

详见 `ioc.csv`。IOC 必须注明来源、类型、是否已验证、检测规则和处置状态。

## 5. 证据与完整性

- 原始 collection 清单：`../00_meta/sha256_manifest.csv`
- ANA 验真结果：`$verificationPath`
- 证据移交记录：`chain_of_custody.csv`
- collection 过程失败记录：

```text
$failureText
```

## 6. 影响范围与处置建议

- [填写：受影响主机、账户、凭据、横向活动]
- [填写：隔离、阻断、凭据轮换、重建或恢复动作]
- [填写：复盘和检测改进]

## 7. 审核

| 角色 | 姓名 | 时间 | 签名 |
|---|---|---|---|
| 分析 |  |  |  |
| 复核 |  |  |  |
| 业务/系统负责人 |  |  |  |
"@
$report | Set-Content -LiteralPath (Join-Path $OutputDir 'report.md') -Encoding UTF8

if (-not (Test-Path -LiteralPath (Join-Path $OutputDir 'timeline.csv'))) {
    'Timestamp,Host,Account,Event,EvidencePath,Confidence,Analyst,Notes' |
        Set-Content -LiteralPath (Join-Path $OutputDir 'timeline.csv') -Encoding UTF8
}
if (-not (Test-Path -LiteralPath (Join-Path $OutputDir 'ioc.csv'))) {
    'Type,Value,SourceEvidence,FirstSeen,LastSeen,Confidence,Action,Status,Notes' |
        Set-Content -LiteralPath (Join-Path $OutputDir 'ioc.csv') -Encoding UTF8
}
if (-not (Test-Path -LiteralPath (Join-Path $OutputDir 'chain_of_custody.csv'))) {
    'Timestamp,Operator,Action,EvidenceID,Description,SourcePath,SHA256,DestinationPath,Receiver,Notes' |
        Set-Content -LiteralPath (Join-Path $OutputDir 'chain_of_custody.csv') -Encoding UTF8
}

Write-Host "REP output: $OutputDir" -ForegroundColor Green
