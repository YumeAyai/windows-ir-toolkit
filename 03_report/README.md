# 03_report — 证据整理与报告

本阶段把 collection 证据和 analysis 结果整理成可审阅的报告工作目录。默认输出在案件目录旁的 `<案件名>-report`，不改变原始案件目录，也不替分析人员下结论。

## 入口

```powershell
powershell -ExecutionPolicy Bypass -File .\build_report.ps1 `
  -CaseDir D:\Cases\IR-001 `
  -AnalysisDir D:\Cases\IR-001-analysis
```

## 输出

```text
<案件名>-report/
├── report.md              报告骨架与证据引用
├── timeline.csv           统一时间线
├── ioc.csv                IOC 与处置状态
└── chain_of_custody.csv   证据移交、验真、存储记录
```

报告中必须区分：事实、推断、待验证项和结论。`sha256_manifest.csv` 是 collection 生成的原始清单，`hash_verification.csv` 是 analysis 对它的验真结果，两者都应作为附件留存。
