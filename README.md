# Windows IR Toolkit

Windows 应急响应包，只有三个阶段：

```text
01_collection 现场采集 → 02_analysis 分析研判 → 03_report 证据整理与报告
```

## 先记住这条

在确认主机正在运行且需要保留内存证据时：记录时间与操作者 → 隔离网络（不要关机）→ 把工具包接入受害机 → 管理员运行 `01_collection\run_collect.bat` → 等待完成 → 只读复制整个案件目录到分析机。

不要在受害机上安装分析工具、打开样本、清理文件或反复重启。若机器已经关机，不要为了“采集内存”再次开机，改为走磁盘镜像流程。

## 三阶段的边界

| 阶段 | 运行位置 | 输入 | 输出 |
|---|---|---|---|
| `01_collection` | 受害 Windows 主机 | 工具包、现场授权 | 一个完整的 `IR-时间戳` 案件目录 |
| `02_analysis` | 隔离分析机 | `01_collection` 案件目录的只读副本 | `<案件名>-analysis`、分析日志、初步发现 |
| `03_report` | 分析机 | collection 案件目录 + analysis 输出 | `<案件名>-report`、时间线、IOC、证据链 |

## 使用顺序

### 01_collection：现场采集

管理员运行：

```bat
01_collection\run_collect.bat
```

脚本会按固定顺序完成：创建案件目录 → 优先采集内存 → 采集系统、进程、网络、持久化、日志和常见用户痕迹 → 写入元数据和日志 → 对全部产物生成 `sha256_manifest.csv`。

默认输出到 `C:\IR_Evidence\IR-时间戳\`。如需指定路径，可直接运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\01_collection\collect.ps1 -CaseDir D:\IR\IR-001
```

### 02_analysis：分析

在分析机上对 collection 产物执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\02_analysis\run_analysis.ps1 `
  -EvidenceDir D:\Cases\IR-001
```

脚本会先验证 collection 的 SHA256 清单，再尝试运行 Volatility 3 的 `info / pslist / pstree / netscan / cmdline / malfind`。默认输出到案件目录旁的 `<案件名>-analysis\`，不会把分析结果写回原始案件目录；单个插件失败不会掩盖其他结果，所有命令和失败原因都会写入分析日志。

### 03_report：整理与报告

```powershell
powershell -ExecutionPolicy Bypass -File .\03_report\build_report.ps1 `
  -CaseDir D:\Cases\IR-001 `
  -AnalysisDir D:\Cases\IR-001-analysis
```

默认输出到案件目录旁的 `<案件名>-report\`，包括 `report.md`、`timeline.csv`、`ioc.csv` 和 `chain_of_custody.csv`。脚本只生成结构和客观统计，不自动把“可疑”写成“已确认入侵”；结论必须由分析人员根据证据填写。

## 目录

```text
01_collection/             现场采集入口、采集脚本、WinPmem、Sysmon（.bat 为 GBK/CRLF）
02_analysis/               内存分析入口、Volatility、symbols
03_report/                 报告生成、时间线、IOC、证据链
install_tools.ps1/.sh      预先准备工具（可选）
tools-manifest.json        工具来源和版本说明
```

Sysmon 只能在事件前部署，属于 `01_collection\sysmon\` 下的可选准备工作；它不是现场采集的必需步骤。

## 重要限制

- 这是现场 triage 工具包，不替代经授权的完整磁盘镜像、网络侧取证或法律证据保全流程。
- 证据目录应使用只读副本进行分析；原始目录和 SHA256 清单不得覆盖。
- U 盘、传输介质和分析机都要记录操作者、时间、路径和 SHA256。

MIT License
