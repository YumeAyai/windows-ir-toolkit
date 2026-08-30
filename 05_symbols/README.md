# 05_symbols

内存分析符号表。

**为什么不放仓里:** 每个 Windows 版本对应 200-500MB 的 symbols,体积过大,且需要按受害机精确版本下载。

**怎么填充:** 现场根据受害机 Windows 版本,从 Volatility 官方仓库下载对应 PDB。详见 `02_collection/collect_artifacts.ps1` 头部注释。
