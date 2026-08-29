# Windows IR Toolkit

Windows 应急响应取证包 — 现场收集 + 内存分析 + 证据链追踪。

## 用法

1. Clone
2. 跑 `install_tools.ps1` 或 `install_tools.sh` 拉取工具
3. 把整个目录拷到 U 盘
4. 受害机以管理员身份运行 `02_collection/acquire.bat`
5. 拷回 `C:\evidence\*` 到分析机

## 目录

| 目录 | 用途 |
|------|------|
| `01_acquire/` | 内存/磁盘 dump 工具 |
| `02_collection/` | PowerShell 证据收集 + 入口 |
| `03_analysis/` | 内存/PE 分析工具 |
| `04_evidence/` | 证据链追踪模板 |
| `05_symbols/` | Volatility 符号表 |

## License

MIT
