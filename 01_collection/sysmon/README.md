# 01_collection/sysmon

Sysmon 应急部署包。

## 用法

管理员双击 `install_sysmon.bat`:
1. 自动从 Microsoft 官网下载 Sysmon
2. 应用本目录的 `sysmon_config.xml` 配置
3. 安装为 `Sysmon64` 服务,启动
4. 立即开始监控,日志在 `Microsoft-Windows-Sysmon/Operational`

## 应急前 vs 应急后

- **应急前装**: 监控到 CS / 木马 / 后门活动,事件 ID 写入 evtx,collect.ps1 自动导出
- **应急后装**: 只能监控后续活动,装前发生的攻击看不到

## 配置要点

- **Event 1** ProcessCreate: 排除常见,关注 PowerShell -enc / mshta / rundll32 等可疑命令行
- **Event 3** NetworkConnect: 全记,排除 windowsupdate / microsoft.com
- **Event 11** FileCreate: 用户目录 + Temp + ProgramData + 可执行后缀
- **Event 12/13/14** Registry: Run / RunOnce / Services / Image File Execution Options
- **Event 22** DnsQuery: 全记
