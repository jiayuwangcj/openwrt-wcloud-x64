# Stable firmware build (2026-10-16)

## Baseline and CI

- OpenWrt **25.12.5**, commit `f0a60eee2fe051741c643ea6118718aae1ef17fb`.
- OpenWrt calls this a supported stable series, not a separately designated LTS.
- GitHub standard hosted **Ubuntu 24.04 LTS**, not retired `ubuntu-20.04`.
- The tag's own `feeds.conf.default` pins all feed commits; do not replace them with moving heads.
- Push to `build/openwrt-25.12.5` (or master after review) triggers compilation.
- No router deployment, external transfer services, automatic release/history deletion,
  `set-output`, or credentials are required.
- Firmware and diagnostics are retained for 14 days on the Actions run.
  There is no automatic public Release publication.

The September `wireguard-v22.03.0` build never obtained a runner and was cancelled
after 24 hours. That branch is preserved, not reused as the new baseline.

## Configuration migration

`config` is a feature seed, replacing generated 22.03-era kernel, GCC, library and
dependency selections. CI runs `make defconfig` and refuses to continue if any
requested setting disappears. Target defaults choose matching hardware drivers.
BIOS/EFI, ext4/squashfs and rootfs tar images remain available, with the original
200 MiB kernel / 1800 MiB rootfs partition sizes.

Core services include PPPoE/IPv6, nginx LuCI/stream, OpenSSH, ZeroTier, OpenVPN,
UPnP and diagnostic tools. `ip-full` replaces `ip-tiny` for JSON route inspection.
APK and `luci-app-package-manager` replace the old opkg UI. Legacy optional themes,
obsolete `luci-ssl-nginx`/`nginx-all-module` names and removed nft-qos/ipset-dns
selections are not carried forward. SQM/CAKE and DNSPod China DDNS are available,
but are not enabled/configured by this repository. No secrets are baked in.

Only matching TUN/CAKE/IFB modules from this build are selected. Kernel WireGuard
and wireguard-tools are excluded. Never copy old `.ko` files or force-install
modules into the new firmware.

Production `highflowd`, `highflow-helper`, private configuration and userspace
`wireguard-go` binaries are **not bundled by this baseline update**. Their packaging,
integrity checks, service paths and migration remain separate work. This is not
a ready-to-flash highflow appliance.

## Upgrade safety: 22.03.0 to 25.12.5

Building is not permission to install. Do not remotely flash/reboot production
wrt1/wrt2, or copy an old overlay wholesale to test this image.

1. Archive VM disks and private `/etc`, SSH keys, firewall includes, DDNS,
   nginx stream configuration and `/overlay/tcp-path-lab` separately and securely.
2. Boot a cloned isolated VM with console access. Prevent duplicate DHCP/PPPoE,
   LAN addresses, ZeroTier identities and WireGuard identities on production links.
3. Verify NIC names/MAC mappings, PPPoE, DHCPv6/PD, routes and firewall zones.
4. Review UCI, nftables includes and nginx modules. APK does not restore old opkg
   packages; do not replay old package/module installation lists.
5. Validate SSH login, trusted tunnel INPUT, CD-only WAN management, DNS rules,
   route leases and fallback connectivity before any deployment.
6. Upgrade only in a console-backed maintenance window with a tested VM rollback.

Old preinit address customization is not copied: recovery addressing is per-node.
Check upstream default LAN addressing before booting an image on an existing LAN.
