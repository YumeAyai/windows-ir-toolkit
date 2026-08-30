# Windows IR Toolkit

Windows 应急响应取证包 — 现场收集 + 内存分析 + 证据链追踪。

应急响应分**两个阶段**:现场取证(受害机)+ 事后分析(分析机)。每个目录对应不同阶段。

## ⚡ 应急三步(慌乱时只看这条)— 阶段 1:现场取证

1. **断网**——拔网线 / 关 WiFi / 断 VPN,**不要关机**
2. **插 U 盘**,管理员双击 `02_collection/acquire.bat`,等它跑完
3. **拔出 U 盘**,把受害机 `C:\evidence\` 整个目录传回分析机

## 怎么准备(出事之前)

1. Clone 本仓库 或从 Releases 下载 `ir-toolkit.zip`
2. 整个目录拷到 U 盘
3. U 盘贴标签"应急取证专用",日常不插电脑,只应急用
4. 在同事/上游/IT 经理那里报备这份资料的位置

## 阶段 1:现场取证(受害机上做)

只用 `01_acquire/` 和 `02_collection/`。

按顺序:

| 步骤 | 动作 | 关键点 |
|------|------|--------|
| 1 | **断网** | 拔网线 / 关 WiFi / 断 VPN。**不关机**——内存里有攻击者痕迹,关机就没了 |
| 2 | **插 U 盘** | 用准备好的 IR_Toolkit U 盘 |
| 3 | **管理员双击** | `02_collection/acquire.bat` → 右键 → 以管理员身份运行 |
| 4 | **等待 5-30 分钟** | 脚本自动 dump 内存 + 收集进程/网络/持久化/日志/文件痕迹,会算 SHA256 |
| 5 | **拔 U 盘** | 取证完成,机器可以关机了 |
| 6 | **传回分析机** | 把受害机 `C:\evidence\IR-时间戳\` 整个目录(含 mem.raw + hash)安全传回 |

## 阶段 2:事后分析(分析机上做)

用 `03_analysis/`、`04_evidence/`、`05_symbols/`。

| 步骤 | 动作 | 用到的目录 |
|------|------|----------|
| 1 | 把 `C:\evidence\IR-时间戳\` 整个目录拷到分析机 | (阶段 1 的产物) |
| 2 | 跑 `05_symbols/download_symbols.ps1` 下载 Volatility symbols(首次) | `05_symbols/` |
| 3 | 用 `03_analysis/` 里的工具做内存/PE 静态分析 | `03_analysis/` |
| 4 | 在 `04_evidence/chain_of_custody.csv` 里登记证据、填写 SHA256 | `04_evidence/` |

**注意:阶段 2 在分析机上做,不在受害机上。** 受害机只跑阶段 1。

## 怎么决策(不同场景)

- **能 RDP / 物理接触** → 按上面"阶段 1 操作步骤"来
- **只有 PowerShell Remoting / SSH 远程** → 在远端跑 `02_collection/collect_artifacts.ps1`,dump 内存用 `01_acquire/winpmem_mini_x64_rc2.exe` 远程执行
- **完全失联 / 黑屏** → 联系机房断电保留磁盘,等恢复后从外部启动介质取证
- **主机已关机** → 不要再开机(开机可能触发恶意软件检测环境变化而自毁或外发),优先做磁盘镜像

## 怎么下载

从 [Releases](../../releases) 下载 `ir-toolkit.zip`,解压即用。或 clone 后跑 `install_tools.ps1` / `.sh` 单独拉取工具。

## 目录对应什么 / 哪个阶段用

| 目录 | 阶段 | 用途 |
|------|------|------|
| `01_acquire/` | 1 现场 | 内存/磁盘 dump 工具(winpmem) |
| `02_collection/` | 1 现场 | PowerShell 证据收集 + 入口 |
| `03_analysis/` | 2 分析 | 内存/PE 分析工具(capa 等) |
| `04_evidence/` | 2 分析 | 证据链追踪模板 |
| `05_symbols/` | 2 分析 | 内存分析符号表(下载脚本) |

## License

MIT
