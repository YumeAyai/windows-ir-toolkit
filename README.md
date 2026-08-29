# Windows IR Toolkit

Windows 应急响应取证包 — 现场收集 + 内存分析 + 证据链追踪。

## ⚡ 应急三步(慌乱时只看这条)

1. **断网**——拔网线 / 关 WiFi / 断 VPN,**不要关机**
2. **插 U 盘**,管理员双击 `02_collection/acquire.bat`,等它跑完
3. **拔出 U 盘**,把 `C:\evidence\` 整个目录传回分析机

## 怎么准备(出事之前)

1. Clone 本仓库 或从 Releases 下载 `ir-toolkit.zip`
2. 整个目录拷到 U 盘
3. U 盘贴标签"应急取证专用",日常不插电脑,只应急用
4. 在同事/上游/IT 经理那里报备这份资料的位置

## 怎么操作(出事时按顺序)

| 步骤 | 动作 | 关键点 |
|------|------|--------|
| 1 | **断网** | 拔网线 / 关 WiFi / 断 VPN。**不关机**——内存里有攻击者痕迹,关机就没了 |
| 2 | **插 U 盘** | 用准备好的 IR_Toolkit U 盘 |
| 3 | **管理员双击** | `02_collection/acquire.bat` → 右键 → 以管理员身份运行 |
| 4 | **等待 5-30 分钟** | 脚本自动 dump 内存 + 收集进程/网络/持久化/日志/文件痕迹,会算 SHA256 |
| 5 | **拔 U 盘** | 取证完成,机器可以关机了 |
| 6 | **传回分析机** | 把 `C:\evidence\CS-时间戳\` 整个目录(含 mem.raw + hash)安全传回 |

## 怎么决策(不同场景)

- **能 RDP / 物理接触** → 按上面"操作步骤"来
- **只有 PowerShell Remoting / SSH 远程** → 在远端跑 `02_collection/collect_artifacts.ps1`,dump 内存用 `01_acquire/winpmem_mini_x64_rc2.exe` 远程执行
- **完全失联 / 黑屏** → 联系机房断电保留磁盘,等恢复后从外部启动介质取证
- **主机已关机** → 不要再开机(开机可能触发恶意软件检测环境变化而自毁或外发),优先做磁盘镜像

## 怎么下载

从 [Releases](../../releases) 下载 `ir-toolkit.zip`,解压即用。或 clone 后跑 `install_tools.ps1` / `.sh` 单独拉取工具。

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
