# IR Toolkit — Windows 应急响应取证包

> 针对 **Cobalt Strike Beacon / RAT 远控木马** 的一键取证工具集。
> 现场取证 SOP + PowerShell 自动化收集 + 链式证据记录。

[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11%20%2F%20Server-blue)]()
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

## 🎯 适用场景

- Cobalt Strike Beacon / Meterpreter / 各类 RAT 远控木马
- 内部主机失陷,需要快速现场取证
- 应急响应初期,需要在断网/隔离后第一时间收集证据
- 配合内存分析(Volatility 3 + CobaltStrikeParser)做后续溯源

## 📦 工具包结构

```
IR_Toolkit/
├── README.md                       ← 本文件
├── LICENSE                         ← MIT
├── 01_acquire/                        ← 内存/磁盘 dump 工具 (空目录,需自行放 exe)
├── 02_collection/
│   ├── collect_artifacts.ps1       ← ★ 主力 PowerShell 脚本(254 行)
│   └── acquire.bat                 ← ★ 管理员双击运行入口
├── 03_analysis/                        ← 现场可选分析工具(Volatility3 / capa)
├── 04_evidence/
│   └── chain_of_custody.csv        ← 证据链追踪模板
└── 05_symbols/                      ← Volatility symbols (可选,体积大)
```

## 🚀 快速开始

### 现场取证 (受害 Windows 主机)

1. **不要关机**,拔网线 / 断 VPN
2. 把整个 `IR_Toolkit` 目录拷到 U 盘
3. 以管理员身份在受害机上 `cd` 到 U 盘目录
4. 双击运行 `02_collection\acquire.bat`
5. 等 5-30 分钟(取决于内存大小)
6. 压缩 `C:\evidence\CS-*\`,传回分析机

### 远程取证 (无现场条件)

```powershell
# PowerShell Remoting
Invoke-Command -ComputerName 10.86.43.209 -FilePath collect_artifacts.ps1 -ArgumentList C:\evidence

# 远程 dump 内存
.\winpmem_mini_x64_rc2.exe \\10.86.43.209\C$\evidence\mem.raw
```

### macOS / Linux 分析端

```bash
# 安装分析工具
pip3 install volatility3 pefile yara-python
brew install yara bulk_extractor
git clone https://github.com/Sentinel-One/CobaltStrikeParser

# 验证镜像 hash
shasum -a 256 mem.raw

# Volatility 分析
vol -f mem.raw windows.pstree        # 进程树(找 rundll32 / dllhost 异常)
vol -f mem.raw windows.netscan       # 网络连接(找 C2 IP)
vol -f mem.raw windows.malfind       # 进程注入

# 提取 Cobalt Strike Beacon 配置
python3 CobaltStrikeParser/CobaltStrikeParser.py -i mem.raw -o cs_config.json
```

## 🔍 收集脚本覆盖范围 (collect_artifacts.ps1)

| 模块 | 内容 | 应急价值 |
|------|------|----------|
| 系统信息 | hostname / whoami / patch level / 时间同步 | 确认资产身份 |
| **进程** | 全进程 + 服务 + DLL + **父子关系树** | ★ 找 `Office → rundll32`、`dllhost` 无参数等 |
| **网络** | netstat / DNS / SMB / RDP / 防火墙 | ★ 找 C2 连接、横向移动痕迹 |
| **持久化** | 注册表 Run / WMI / 服务 / 计划任务 | ★ 找 Beacon 持久化 |
| 日志 | Security / PowerShell / Sysmon / Defender | 4624/4625/4688 + PowerShell 脚本块日志 |
| 文件 | Prefetch / Recent / Temp 目录 | 程序执行历史 + 落地文件 |
| 用户 | PSReadLine 历史 / SSH known_hosts | 历史命令 + 内网跳板 |
| 浏览器 | Chrome / Edge History DB | 钓鱼/水坑溯源 |

## ⚠️ 取证铁律

1. **先断网,后取证**(顺序反了证据可能丢或被外发)
2. **不要关机**(内存数据永久丢失)
3. **就地只读**(镜像存到本地 C:\evidence\,不要在 U 盘就地存)
4. **算 SHA256**(链式证据第一步)
5. **不要装新软件**(污染证据)
6. **不要重连互联网**(等待溯源结果)

## 🧰 工具下载对照表

| 工具 | 用途 | 链接 |
|------|------|------|
| WinPmem | 内存 dump 主力 | https://github.com/Velocidex/WinPmem/releases |
| FTK Imager | 磁盘/内存取证镜像 | https://www.exterro.com/ftk-imager |
| DumpIt | UEFI 兼容备选 | https://www.comae.com/ |
| Magnet RAM Capture | 备选 dump | https://www.magnetforensics.com/ |
| Volatility 3 | 内存分析 | https://github.com/volatilityfoundation/volatility3 |
| CobaltStrikeParser | CS 配置提取 | https://github.com/Sentinel-One/CobaltStrikeParser |
| capa | PE 静态分析 | https://github.com/mandiant/capa |

> 国内网络下 GitHub 不稳,可加镜像前缀: `https://ghproxy.com/https://github.com/...`

## 📋 案例模板

**触发场景**:360AISA 告警 + JA3 fingerprint `a0e9f5d64349fb13191bc781f81f42e1` 命中 8 次

**初始 IOC**:
- 源 IP: `10.86.43.209`
- C2 IP: `20.212.88.141` / `153.3.230.132` / `101.37.44.92`
- JA3 (Cobalt Strike Beacon): `a0e9f5d64349fb13191bc781f81f42e1`
- 伪装 SNI: `*.sginput.qq.com` / `*.browser.360.cn` / `*.pinyin.sogou.com`

**推荐动作**:见 `02_collection/collect_artifacts.ps1` 注释中的 CS 专项 checklist

## 📜 License

MIT
