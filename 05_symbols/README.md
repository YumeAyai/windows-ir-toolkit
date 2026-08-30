# 05_symbols

内存分析符号表。

**zip 自带 `download_symbols.ps1`,现场首次分析时跑一次即可**(30 秒到 1 分钟):

```powershell
cd 05_symbols
powershell -ExecutionPolicy Bypass -File download_symbols.ps1
```

脚本会自动检测受害机 Windows 版本,下载对应 symbols 到当前目录。
网络隔离时,去 https://downloads.volatilityfoundation.org/volatility3/symbols/ 手动下 `windows-*.zip`,放到本目录即可。
