# Stable firmware build (updated 2026-10-25)

## Baseline and CI

- OpenWrt **25.12.6**, commit `64900e756efa667774214f9c6b17c113222e01f7`.
- OpenWrt calls this a supported stable series, not a separately designated LTS.
- GitHub standard hosted **Ubuntu 24.04 LTS**, not retired `ubuntu-20.04`.
- The tag's own `feeds.conf.default` pins all feed commits; do not replace them with moving heads.
- Ongoing maintenance and build-triggering pushes use `master`.
- No router deployment, external transfer services, automatic release/history deletion,
  `set-output`, or credentials are required.
- Firmware and diagnostics are retained for 14 days on the Actions run, unless
  the run is deleted sooner (which also removes its artifacts).
- After the build and firmware validation succeed, a separate job with
  `contents: write` downloads and rechecks the firmware, uploads all image and
  provenance files to a draft Release, then publishes it as Latest. Release tags
  contain the OpenWrt version, run ID and run attempt. Releases are not automatically
  deleted. Download images from the repository Releases page for long-term access.

The September `wireguard-v22.03.0` build never obtained a runner and was cancelled
after 24 hours. That branch is preserved, not reused as the new baseline.

## Configuration migration

`config` is a feature seed, replacing generated 22.03-era kernel, GCC, library and
dependency selections. CI runs `make defconfig` and refuses to continue if any
requested setting disappears. Target defaults choose matching hardware drivers.
BIOS/EFI, ext4/squashfs and rootfs tar images remain available, with the original
200 MiB kernel / 1800 MiB rootfs partition sizes.
OpenWrt LXC deployment was abandoned on 2026-10-25; rootfs tar remains a
generic artifact, not a maintained LXC deployment path. See
[the LXC decision record](lxc-status.md).

The first CI run passed runner/dependency/feed preparation and caught the removed
`GRUB_SERIAL` symbol during strict validation. The obsolete setting was removed
instead of disabling validation; serial device defaults now come from the target.

Core services include PPPoE/IPv6, nginx LuCI/stream, OpenSSH, ZeroTier, OpenVPN,
UPnP and diagnostic tools. `ip-full` replaces `ip-tiny` for JSON route inspection.
APK and `luci-app-package-manager` replace the old opkg UI. Legacy optional themes,
obsolete `luci-ssl-nginx`/`nginx-all-module` names and removed nft-qos/ipset-dns
selections are not carried forward. Available legacy themes are restored after the
backup audit. SQM/CAKE, SmartDNS and DNSPod China DDNS are installed,
but are not enabled/configured by this repository. No secrets are baked in.

The firmware now includes standard `kmod-wireguard`, `wireguard-tools` and
`luci-proto-wireguard`, alongside matching TUN/CAKE/IFB modules from this build.
These modules are compiled against the same kernel and ABI as the image; never
copy old `.ko` files or force-install modules into the new firmware. CI checks both
the resolved configuration and final image manifests for every explicitly selected
package, including WireGuard, SQM and the restored backup applications.

Production `highflowd`, `highflow-helper`, private configuration and userspace
`wireguard-go` binaries are **not bundled by this baseline update**. Their packaging,
integrity checks, service paths and migration remain separate work. This is not
a ready-to-flash highflow appliance.

Standard WireGuard is available for future netifd/UCI/LuCI configuration, but no
tunnel, key, address, route, firewall change or peer identity is preconfigured.
The production userspace tunnel remains untouched. Its qualification/port-handoff,
supervision and route-lease workflow is not automatically replaced by stock WireGuard.
Validate any transition in an isolated console-backed VM before changing production.

## Upgrade safety: 22.03.0 to 25.12.6

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

## Backup package audit (2026-10-25)

See [package-audit.md](package-audit.md) for the verified backup inventory,
restored applications, changed package names and services requiring migration.
