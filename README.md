# Windows IR Toolkit

Windows 应急响应取证包 — 现场收集 + 内存分析 + 证据链追踪。

> ⚠️ **目录编号 ≠ 使用顺序**。`01-05` 只是历史命名编号,不代表先后。

## ⚡ 应急三步(慌乱时只看这条)

1. **断网**——拔网线 / 关 WiFi / 断 VPN,**不要关机**
2. **插 U 盘**,管理员双击 `02_collection/acquire.bat`,等它跑完
3. **拔出 U 盘**,把受害机 `C:\evidence\` 整个目录传回分析机

## 怎么准备(出事之前)

1. Clone 本仓库 或从 Releases 下载 `ir-toolkit.zip`
2. 整个目录拷到 U 盘
3. U 盘贴标签"应急取证专用",日常不插电脑
4. 在同事/上游/IT 经理那里报备这份资料的位置

## 完整流程(按使用顺序)

| 顺序 | 阶段 | 目录 | 在哪台机 | 干什么 |
|------|------|------|---------|--------|
| 0 | (可选预装) | `01_acquire/sysmon/install_sysmon.bat` | 受害机 | 装 sysmon 监控(应急前装,事件 ID 写入 evtx) |
| 1 | **现场取证** | `02_collection/acquire.bat` | 受害机 | 双击入口:自动提权 + 跑收集脚本 + 调 winpmem + 算 hash |
| 2 | (传输) | 现场产物 | — | `C:\evidence\IR-时间戳\` 7z 加密拷到分析机 |
| 3 | **分析准备** | `05_symbols/download_symbols.ps1` | 分析机 | 下载受害机 Windows 版本对应的 Volatility symbols |
| 4 | **内存分析** | `03_analysis/` | 分析机 | vol + CobaltStrikeParser + capa |
| 5 | **证据登记** | `04_evidence/chain_of_custody.csv` | 分析机 | 填案件 / SHA256 / 分析师签名 |
| 6 | (报告) | — | 分析机 | 整合时间线 + IOC + 处置建议 |

## 目录用途速查

| 目录 | 阶段 | 工具/内容 | 性质 |
|------|------|----------|------|
| `01_acquire/` | 0 现场(可选) | winpmem + sysmon 一键部署 | 工具(被 02 调用) |
| `02_collection/` | 1 现场 | 入口 bat + 254 行 ps1 | **现场入口** |
| `03_analysis/` | 4 分析 | capa(workflow 自动装) | 分析工具 |
| `04_evidence/` | 5 收尾 | chain_of_custody.csv 模板 | 证据链(只有 1 个 csv) |
| `05_symbols/` | 3 分析 | download_symbols.ps1 | Volatility symbols 下载 |

## 阶段 1:现场取证(受害机)

按顺序:

| 步骤 | 动作 | 关键点 |
|------|------|--------|
| 1 | **断网** | 拔网线 / 关 WiFi / 断 VPN。**不关机**——内存里有攻击者痕迹 |
| 2 | **插 U 盘** | 用准备好的 IR_Toolkit U 盘 |
| 3 | **管理员双击** | `02_collection/acquire.bat` → 右键 → 以管理员身份运行 |
| 4 | **等待 5-30 分钟** | 脚本自动 dump 内存 + 收集 8 大块 artifacts + 算 SHA256 |
| 5 | **拔 U 盘** | 取证完成,机器可以关机 |
| 6 | **传回分析机** | `C:\evidence\IR-时间戳\` 整目录(含 mem.raw + hash)安全传回 |

## 阶段 2:事后分析(分析机)

按 **05 → 03 → 04** 顺序(注意 05 在 03 前):

| 步骤 | 动作 | 用到的目录 |
|------|------|----------|
| 1 | 解压现场产物,`cd IR-时间戳/` | — |
| 2 | 跑 `05_symbols/download_symbols.ps1` 下 symbols | `05_symbols/` |
| 3 | 跑 vol + CobaltStrikeParser + capa | `03_analysis/` |
| 4 | 填 `04_evidence/chain_of_custody.csv` | `04_evidence/` |
| 5 | 整合时间线 + IOC + 写事故报告 | — |

## 怎么决策(不同现场场景)

- **能 RDP / 物理接触** → 按阶段 1 操作步骤来
- **只有 PowerShell Remoting / SSH 远程** → 在远端跑 `02_collection/collect_artifacts.ps1`,dump 内存用 `01_acquire/winpmem_mini_x64_rc2.exe` 远程执行
- **完全失联 / 黑屏** → 联系机房断电保留磁盘,等恢复后从外部启动介质取证
- **主机已关机** → 不要再开机(可能触发恶意软件检测环境变化而自毁或外发),优先做磁盘镜像

## 怎么下载

从 [Releases](../../releases) 下载 `ir-toolkit.zip`,解压即用。或 clone 后跑 `install_tools.ps1` / `.sh` 单独拉取工具。

## License

MIT
