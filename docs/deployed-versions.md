# Observed deployed versions — 2026-10-25

These are read-only observations of the routers, not a deployment of this
repository's newer firmware. Device tags below identify this deployment record;
they do **not** claim that checking out the tag reproduces the old firmware.
The exact original configuration commit/image checksum is unknown. Neither the
September build branch nor the newer 25.12.5 branch can be presented as that
original source without evidence.

| Device | Running record tag | OpenWrt | Revision | Kernel | Boot/root | NIC |
| --- | --- | --- | --- | --- | --- | --- |
| wrt1 | `wrt1-running-22.03.0-20261025` | 22.03.0 | r19685-512e76967f | 5.10.138 | BIOS / SquashFS | vmxnet3 |
| wrt2 | `wrt2-running-22.03.0-20261025` | 22.03.0 | r19685-512e76967f | 5.10.138 | BIOS / SquashFS | virtio_net |

Both use x86/64. The verified private backup snapshot is
`router-backups/20261016-1128`; inventory counts/hashes are in
[package-audit.md](package-audit.md). Configuration, identities and keys remain
outside Git. Routine maintenance is on `master`. New firmware Releases identify
actual build commits, run IDs, pinned upstream commits and checksums separately.
Add a new immutable device running-record tag after a confirmed future upgrade;
do not move the historical running tags to an uninstalled firmware build.
