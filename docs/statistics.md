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

## 用户态 WireGuard 重建后的 SQM 恢复

`files/etc/hotplug.d/net/30-sqm-highflow` 监听内核网卡 `add`，仅处理
`wg-highflow` TUN。守护程序直接创建网卡，不通过 netifd，因此没有逻辑
接口 `ifup` 事件供原生 `/etc/hotplug.d/iface/11-sqm` 使用。

钩子要求 SQM 已开机启用，且仅有一个启用的匹配 CAKE 配置；调用原生
`run.sh stop wg-highflow` 清理残留状态，再 `start wg-highflow`，验证上传
CAKE、下载 IFB CAKE 及 ingress 重定向。速率读取 UCI，不写死带宽。
仅锁定本钩子，用 ifindex 检查接口身份；同一实例已恢复且队列仍在时跳过。
停止、启动、验证异常分别记录唯一 `SQMH_*` 错误并退出，不循环重试。
原生 run.sh 遍历到最后一个非目标队列时可能返回 1，即使目标已经启动；
仅在设备身份和队列读取验证成功时接受该状态，并记录 native_start_status。

不响应其他网卡、remove 或 change，不生成 netifd ifup，不重启全局 SQM、
网络、防火墙、拨号或高速通道。首次部署可单独模拟该脚本的 add 事件，
不要为验证它而重建生产 WG；真实重建事件留待自然重连验证。
现网将此文件加入 sysupgrade.conf；固件构建自动复制 `files/` 到镜像。

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
