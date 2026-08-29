# Windows IR Toolkit

Windows 应急响应取证包 — 现场收集 + 内存分析 + 证据链追踪。

## 用法

从 [Releases](../../releases) 下载 `ir-toolkit.zip`,解压,拷 U 盘,管理员双击 `02_collection/acquire.bat`。

或 clone 后跑 `install_tools.ps1` / `.sh` 单独拉取工具。

## 目录

| 目录 | 用途 |
|------|------|
| `01_acquire/` | 内存/磁盘 dump 工具 |
| `02_collection/` | PowerShell 证据收集 + 入口 |
| `03_analysis/` | 内存/PE 分析工具 |
| `04_evidence/` | 证据链追踪模板 |
| `05_symbols/` | 内存分析符号表 |

## License

MIT
