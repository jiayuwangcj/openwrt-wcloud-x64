# Backup software audit — 2026-10-25

## Evidence

The local full backups at `router-backups/20261016-1128` were checked against
all entries in their SHA256SUMS file before comparison. Private archives,
credentials and device configuration are not committed to this repository.

| Device | Installed packages in backup | Inventory SHA256 |
| --- | ---: | --- |
| wrt1 | 282 | `d9df0445d8f7b4deeac94a5405babade6195b2973e577b14d23d71993f8ad918` |
| wrt2 | 311 | `e7dc83df54da6008019a648d9ccacb0bb782e5d6761a531c3757a3866a8e92a8` |

Both devices were also inspected read-only on 2026-10-25: OpenWrt 22.03.0,
revision r19685-512e76967f, kernel 5.10.138, x86/64, BIOS, SquashFS.
Their existing installed firmware is not the new 25.12.5 build.

## Packages restored or explicitly required

- SQM: `luci-app-sqm`, `sqm-scripts`, `kmod-sched-core`, `kmod-sched-cake`,
  `kmod-ifb`, `tc-full`, with dependencies resolved from release-pinned feeds.
  The previous seed already requested the SQM UI, CAKE, IFB and tc-full;
  the scripts and scheduler core are now explicit requirements as well.
  SQM is not automatically enabled or given interface names/bandwidth values.
- DNS: `smartdns`, `luci-app-smartdns`. SmartDNS is enabled on wrt2; its
  dnsmasq has DNS disabled (`port=0`). Restoring only dnsmasq would not
  reproduce wrt2's current DNS service.
- Utilities: `htop`, `tree`, `wget-ssl`, `wakeonlan`, `lrzsz`, `python3`,
  `ipip`, `pppstats`. Python, Perl and library dependencies are resolved for
  the new release instead of copying 22.03 binaries or shared libraries.
- Compatibility: `ipset`, `iptables-nft`, `ip6tables-nft` for existing tools.
- Proxy: `sing-box` was found as an unmanaged ELF executable in wrt2's
  overlay, not in its opkg inventory. The new image selects the pinned feed's
  package. wrt2 reports 1.8.13; the 25.12.6 pinned feed is 1.13.21. Its service is
  currently disabled. Old config must be migrated and checked before enabling
  it; the old init script and binary are not blindly restored.
- UI: available Material, OpenWrt and OpenWrt 2020 themes, plus UPnP Chinese
  translation, retained alongside Bootstrap.
- Already selected: OpenSSH, ZeroTier, OpenVPN, PPPoE/IPv6, DNSPod DDNS,
  nginx LuCI and stream support, UPnP, curl, dig, iperf3, tcpdump, iftop,
  socat, bash/zsh, git and subversion.

Every package explicitly selected in `config` is checked after defconfig and
again against every final firmware manifest before publishing. Tests reject
missing SQM components, SmartDNS and WireGuard even if the image files exist.

## Script runtime and diagnostic dependencies

Additional explicit selections: jq; tmux; strace/lsof/ss; full ip and tc plus
ip-bridge; ping/arping/tracepath, MTR JSON and nmap; ethtool and conntrack;
rsync and SFTP; Python pip/venv; tar/gzip/xz/zstd/unzip; file/xxd;
procps ps/pgrep/pkill/watch/vmstat; GNU timeout/stat/base64/sha256sum/date/sleep/
readlink/mktemp/nohup/env/tr/dd; find/xargs, diff/patch, gawk/sed, flock/getopt.
Existing tcpdump, iperf3, dig, curl, socat, bash and zsh remain selected.
These are reusable runtime/diagnostic tools, not private scripts or credentials.

An actual `make defconfig` against source 64900e75 and the same pinned feed
commits accepted every requested setting and selected 428 packages. No target
firmware was compiled locally. Of the original installed names, 210/282 on
wrt1 and 232/311 on wrt2 appear unchanged; the remainder consists of renamed
libraries/frameworks or the legacy components listed below. All original
`kmod-*` package names from both inventories are now selected. In particular,
wrt1's live NICs both use `vmxnet3`; its driver must be explicit because the
new x86 defaults do not select it. wrt2 uses virtio_net.

## Changed or inactive legacy components

- `ip-tiny` is replaced by `ip-full`; opkg/LuCI opkg by APK and
  `luci-app-package-manager`. Versioned shared libraries and matching kernel
  modules are provided by new-release dependency resolution, not old names.
- Python now resolves to the release version. Old standalone `python3-cgi`,
  `python3-cgitb` and `python3-distutils` packages are absent; scripts importing
  these removed stdlib modules need code migration, not old binary restoration.
- Old Lua LuCI compatibility/library packages are not carried forward without
  an app that needs them; selected current LuCI apps resolve their own framework.
- `nginx-all-module` and old LuCI SSL package names are replaced by selected
  nginx SSL/LuCI packages and explicit stream support. Device-specific nginx
  forwarding config and certificates remain private migration material.
- `ipset-dns` is absent from the release-pinned packages feed. Both live
  devices retain its init/config, but neither has a running process, populated
  ipset list or detected rules referencing its `domain-filter-*` sets.
  wrt1 uses dnsmasq; wrt2 uses SmartDNS. It is inactive legacy configuration,
  not a current DNS/highflow dependency. It is not restored to the new image.
- `nft-qos` and its LuCI app are absent from the pinned feeds. wrt1's backed-up
  MAC limiting, priority and general limiting switches are all zero. SQM/CAKE
  supplies the newly requested shaping facility; old nft-qos UCI is not
  automatically translated to SQM.

## Private/custom services still require separate migration

The package inventory does not describe all software: the overlay also holds
`highflowd`, `highflow-helper`, private userspace WireGuard executables and
launcher/watchdog scripts, plus a custom `/usr/bin/ddns` script. The new image
contains standard kernel WireGuard, not those privately deployed programs.
Their binaries/configuration, ZeroTier identities, SSH keys, nginx forwarding,
firewall includes and service supervision must be restored selectively from
private backups and validated in an isolated VM. No old overlay or `.ko` files
should be copied wholesale. This audit does not install or reboot either router.
