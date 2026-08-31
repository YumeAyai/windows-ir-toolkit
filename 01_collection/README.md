# 01_collection — 现场采集

本阶段只负责在受害 Windows 主机上采集现场证据，不做分析、不清理主机。

## 入口

管理员运行：

```bat
run_collect.bat
```

默认输出：`C:\IR_Evidence\IR-时间戳\`。

采集顺序固定为：

```text
创建案件目录 → 内存 → 系统/进程/网络/持久化 → 日志/文件痕迹 → SHA256 清单
```

内存工具应放在 `tools\winpmem_mini_x64_rc2.exe`。找不到工具时，脚本仍会采集非易失性证据，并在 `00_meta\collection.log` 中明确记录内存失败原因。

## 输出结构

```text
IR-时间戳/
├── 00_meta/        collection.log、collection.json、sha256_manifest.csv
├── 01_memory/      mem.raw、memory.log
├── 02_system/      主机、账户、补丁、时间信息
├── 03_process/     进程、命令行、服务、进程树
├── 04_network/     连接、DNS、路由、防火墙、会话
├── 05_persistence  计划任务、服务、Run/WMI 持久化
├── 06_logs/        EVTX 和近期安全事件
└── 07_files/       Prefetch、PowerShell 历史、浏览器历史等
```

采集完成后，记录操作者和时间，安全复制整个案件目录到分析机。不要只复制 `mem.raw`，否则证据链和采集上下文会断裂。

## 可选：事件前部署 Sysmon

`sysmon\install_sysmon.bat` 仅用于事件前准备。应根据组织的白名单、日志保留周期和变更流程审核 `sysmon_config.xml`；应急发生后安装 Sysmon 不能补回安装前的事件。
