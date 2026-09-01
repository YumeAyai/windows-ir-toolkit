# 02_analysis — 分析研判

本阶段在隔离分析机运行。输入是 `01_collection` 产生的案件目录只读副本，输出默认写入案件目录旁的 `<案件名>-analysis` 目录。

## 入口

```powershell
powershell -ExecutionPolicy Bypass -File .\run_analysis.ps1 `
  -EvidenceDir D:\Cases\IR-001
```

脚本先验 hash，再运行可用的 Volatility 3 插件。默认插件为：

```text
windows.info
windows.pslist
windows.pstree
windows.netscan
windows.cmdline
windows.malfind
```

Volatility 不可用、symbols 缺失或某个插件失败时，脚本会保留已完成结果并记录失败，不会删除或修改原始证据。

如需对已授权的单个样本做 capa 静态分析，显式传入 `-SamplePath`；不要让脚本自动扫描整个案件目录：

```powershell
powershell -ExecutionPolicy Bypass -File .\run_analysis.ps1 `
  -EvidenceDir D:\Cases\IR-001 `
  -SamplePath D:\Samples\suspect.exe
```

## 工具准备

- Windows：发布包已包含 `vol.py`、便携 Python、Volatility 3 及其依赖；也可把独立的 `vol.exe` 放入 `02_analysis\tools\`。
- WinPmem 只属于 collection，不要在分析机重新对案件目录执行采集脚本。
- 分析包不预置整套 Windows symbols 数据（体积过大）；缺少的 Windows symbols 由 Volatility 在联网时自动解析并缓存。symbols 不属于受害机证据，也不应写回 collection 案件目录。

## 输出

```text
analysis/
├── 00_meta/       input_manifest.csv、hash_verification.csv、analysis.log
└── volatility/    每个插件一个 txt 结果文件
```
