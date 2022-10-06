# 个人使用，一些pve lxc相关入门脚本

**English** | [中文](https://p3terx.com/archives/build-openwrt-with-github-actions.html)

## PVE shell use lxc scripts

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
