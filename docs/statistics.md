# 统计组件固化 — 2026-10-26

固件包含 `luci-app-statistics`、collectd、RRDTool，以及 exec、sqm、cpu、
load、memory、interface、ping、conntrack、processes、df 插件。依赖由固定
版本 feeds 解析；不加入温度插件，不额外选择内核模块。

## TASKSTATS

选择 `CONFIG_KERNEL_TASKSTATS=y`、`CONFIG_KERNEL_TASK_DELAY_ACCT=y`、
`CONFIG_KERNEL_TASK_IO_ACCOUNTING=y` 和 `CONFIG_KERNEL_TASK_XACCT=y`。
这是新内核的内置能力，供 Processes 插件读取扩展记账信息，不是向旧内核
强装 `.ko`。完整延迟统计还取决于内核运行时是否启用 delay accounting；
本次不预设 sysctl、不修改现网内核参数。

所有选项都受现有 defconfig 检查约束，缺失时 CI 失败。
编译后必须安装匹配的新固件才能获得该能力，仅安装统计包无法增加它。

## SQM 采集兼容性

构建准备阶段对 release 固定版本的 `sqm_collectd.sh` 作两处读取修正：

- `tc -s -j qdisc show dev ... root` 仅读取根队列，避免 root CAKE 与 ingress
  同时存在时被当成一个 JSON 对象解析。
- 缺失的 backlog 输出 RRD 未知值 `U`，避免空数值造成写入错误。

修正不执行 tc add/change/delete。上游实现不符合已审查文本时停止构建，
不会静默继续。脚本属于 SQM 采集包，因此无需在固件中再复制第二套脚本。

## 配置与迁移

菜单：Statistics → Graphs / Setup。采样间隔建议 30 秒，存储目录
`/tmp/rrd`，备份开关在 Output plugins → RRDTool。
RRD 是固定大小的循环数据库；关闭备份时重启丢失历史。

现网配置保存在 `/etc/config/luci_statistics`，按常规 sysupgrade 配置备份
恢复。设备相关接口、Ping 目标和进程列表不写入通用镜像，避免 wrt1/wrt2
混用；也不覆盖网络、PPPoE、路由、防火墙、SSH 或高速通道配置。

此前手工部署的 `/usr/libexec/collectd/sqm_collectd_root.sh` 若仍被 UCI 引用，
升级时应保留该文件（现网已在 sysupgrade.conf 中登记）。新固件原生脚本
同样带修正；后续可单独审查迁移 UCI 引用，不在升级时自动改写。

本次仅更新固件工程，未刷写任何路由器，未运行内核加载或网络重启操作。
