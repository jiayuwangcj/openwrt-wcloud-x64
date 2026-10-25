# OpenWrt x86_64 固件与部署记录

## 当前固件构建

构建基线已更新至 **OpenWrt 25.12.6 / x86_64**，GitHub Actions 使用
Ubuntu 24.04 LTS，后续统一在 `master` 维护。只有推送到 `master` 的最新提交
信息包含 `[publish]` 标记时才启动构建；普通提交会跳过构建和发布。
构建并校验通过后，镜像、SHA256 校验文件及构建来源会自动发布到
[Releases](https://github.com/jiayuwangcj/openwrt-wcloud-x64/releases)。
固件和诊断文件也可在对应 Actions 页的 Artifacts 下载（保留 14 天；删除构建记录也会删除产物）。
不自动刷写路由器，也不自动删除 Release。

需要发布时，在完成审查的代码上创建带标记的提交，例如：

```bash
git commit --allow-empty -m "[publish] Build reviewed OpenWrt firmware"
git push origin master
```

标记检查推送后的最新提交信息；同一次推送中较早提交的标记不会触发。
允许空提交触发发布，不再限制修改文件路径，也不提供手动 Run workflow 绕过标记。

从现有 22.03.0 跨版本升级存在配置、APK 包管理及内核模块兼容风险，
必须先在隔离虚拟机验证；完整说明见 [稳定版构建与升级安全](docs/stable-build.md)。
软件已按 2026-10-16 全量备份核对，包含 SQM/CAKE、SmartDNS、Python 和常用工具；
差异与迁移事项见 [备份软件核对](docs/package-audit.md)。
SQM 默认不启用，需配置接口和上下行速率。
设备当前版本及标签见 [部署版本记录](docs/deployed-versions.md)。
当前更新不包含生产高速通道守护进程与私有配置的固件打包。
固件已选择标准内核 WireGuard、wireguard-tools 及 LuCI 协议支持，
但不预设隧道、密钥或路由；现有 userspace 高速通道不自动迁移。

上游同步及安全审查见 [上游审查记录](docs/upstream-review.md)。

以下内容为历史模板说明。

**English** | [中文](https://p3terx.com/archives/build-openwrt-with-github-actions.html)

## LXC 历史实验（已放弃，2026-10-25）

已决定停止推进 OpenWrt LXC 部署，继续使用虚拟机。根据此前实际测试，
LXC 相比虚拟机的性能提升不超过 10%，家用场景无明显收益；共享宿主机
内核带来的隔离性损失不值得交换这部分性能。详见 [LXC 停止推进记录](docs/lxc-status.md)。

以下命令和 `pve/200.conf` 仅作历史存档，不作为当前部署指南。

``` bash
pveam list # 显示所有可用的lxc模版
pveperf # 简单性能测试

# 在ubuntu上用unsquashfs 创建的lxc容器似乎有问题，无法启动，还是在pve上直接创建吧
apt install squashfs-tools
unsquashfs openwrt-x86-64-generic-squashfs-rootfs.img
cd squashfs-root
tar zcf ../openwrt201117.rootfs.tar.gz *
cd ..
mv /var/lib/vz/template/cache /var/lib/vz/template/cache
pveam list local  # 显示已经在本地的模版


# 以下开始创建lxc容器
pct create 202 local:vztmpl/openwrt201117.rootfs.tar.gz --rootfs local-lvm:1 --ostype unmanaged --hostname CTOpenWrt --arch amd64 --cores 2 --memory 512 --swap 0 -net0 bridge=vmbr0,name=eth0

# 这里需要更新pve版本，否则无法创建
pct create 101 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst --rootfs local-lvm:100 -cores 4 -memory 4096 --swap 8192 -net0 bridge=vmbr0,name=eth0,ip=192.168.10.9/24,gw=192.168.10.2 -ostype ubuntu -hostname ubuntu22 -password


```

## Actions-OpenWrt

[![LICENSE](https://img.shields.io/github/license/mashape/apistatus.svg?style=flat-square&label=LICENSE)](https://github.com/P3TERX/Actions-OpenWrt/blob/master/LICENSE)
![GitHub Stars](https://img.shields.io/github/stars/P3TERX/Actions-OpenWrt.svg?style=flat-square&label=Stars&logo=github)
![GitHub Forks](https://img.shields.io/github/forks/P3TERX/Actions-OpenWrt.svg?style=flat-square&label=Forks&logo=github)

A template for building OpenWrt with GitHub Actions

## Usage

- Click the [Use this template](https://github.com/P3TERX/Actions-OpenWrt/generate) button to create a new repository.
- Generate `.config` files using [Lean's OpenWrt](https://github.com/coolsnowwolf/lede) source code. ( You can change it through environment variables in the workflow file. )
- Push `.config` file to the GitHub repository.
- Select `Build OpenWrt` on the Actions page.
- Click the `Run workflow` button.
- When the build is complete, click the `Artifacts` button in the upper right corner of the Actions page to download the binaries.

## Tips

- It may take a long time to create a `.config` file and build the OpenWrt firmware. Thus, before create repository to build your own firmware, you may check out if others have already built it which meet your needs by simply [search `Actions-Openwrt` in GitHub](https://github.com/search?q=Actions-openwrt).
- Add some meta info of your built firmware (such as firmware architecture and installed packages) to your repository introduction, this will save others' time.

## Credits

- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub Actions](https://github.com/features/actions)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [Lean's OpenWrt](https://github.com/coolsnowwolf/lede)
- [tmate](https://github.com/tmate-io/tmate)
- [mxschmitt/action-tmate](https://github.com/mxschmitt/action-tmate)
- [csexton/debugger-action](https://github.com/csexton/debugger-action)
- [Cowtransfer](https://cowtransfer.com)
- [WeTransfer](https://wetransfer.com/)
- [Mikubill/transfer](https://github.com/Mikubill/transfer)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [ActionsRML/delete-workflow-runs](https://github.com/ActionsRML/delete-workflow-runs)
- [dev-drprasad/delete-older-releases](https://github.com/dev-drprasad/delete-older-releases)
- [peter-evans/repository-dispatch](https://github.com/peter-evans/repository-dispatch)

## License

[MIT](https://github.com/P3TERX/Actions-OpenWrt/blob/main/LICENSE) © [**P3TERX**](https://p3terx.com)
