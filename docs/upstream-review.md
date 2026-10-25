# Upstream review — 2026-10-25

## Build-template lineage

GitHub reports this repository as independent (`fork=false`). Its README and
workflow headers identify [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)
as the template source. That repository is archived; its latest commit is
[`decaa5c260`](https://github.com/P3TERX/Actions-OpenWrt/commit/decaa5c260535c302a0d59d53b598bb409fd54dd),
dated 2024-03-02.

Its last functional changes modernized the runner/dependency installation,
removed remote debugging/external transfers, replaced set-output, and updated
release/artifact actions. This project already implements those capabilities
with Ubuntu 24.04, explicit dependencies, release-pinned feeds, minimal job
permissions and validated Release uploads. The upstream MIT attribution year is
updated. Optional unpinned third-party feeds, moving action refs, aggressive
run/Release deletion and old cache versions are excluded from the synchronization.
The customized build flow remains intact.

## Firmware update adopted

Adopted the signed official [OpenWrt v25.12.6 service release](https://github.com/openwrt/openwrt/releases/tag/v25.12.6),
published 2026-10-18. Tag object `22dd0e28678a6cd6fbadea2d5aaded3a805ab8a4`
points to `64900e756efa667774214f9c6b17c113222e01f7`; GitHub reports the
signature verified and valid. CI checks the cloned commit against that fixed SHA.

Relevant fixes include kernel 6.12.112, OpenSSL 3.5.9, rpcd/CGI/LuCI and DDNS
security fixes, plus updated networking/runtime packages. This stays in the
25.12 stable series. New DHCP client-ID controls preserve the prior series'
default behavior; interface/ISP compatibility still needs VM testing.

The new tag supplies these fixed feed commits:

| Feed | Commit |
| --- | --- |
| packages | `093d551675b1119a06ef224d419905e8d6b2af1a` |
| luci | `75a306df84a020c57a631ef5b4c02ace56d93387` |
| routing | `48c808034414a2112cf9d5261a20a320e8d0d170` |
| telephony | `2618106d5846a4a542fdf5809f0d3ed228ce439b` |
| video | `094bf58da6682f895255a35a84349a79dab4bf95` |

Local configuration resolution with these exact sources/feeds passed all
requested settings, selected 428 packages and retained every old kernel-module
package name in both backup inventories. No target firmware was compiled locally.
CI must still compile the image and pass package-manifest/checksum validation.
This source/configuration review is not a live-device boot or migration test.

## Actions updates adopted

Reviewed official action release notes, runtime requirements and inputs:

| Action | Reviewed release | Pinned commit |
| --- | --- | --- |
| [checkout](https://github.com/actions/checkout/tree/v7.0.1) | 7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| [upload-artifact](https://github.com/actions/upload-artifact/tree/v7.0.2) | 7.0.2 | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` |
| [download-artifact](https://github.com/actions/download-artifact/tree/v8.0.2) | 8.0.2 | `9000827ccba6bdab643e8b6fd33ac0654aef8333` |

These use Node 24 on GitHub-hosted Ubuntu 24.04. Checkout credential persistence
is disabled. Upload keeps the compatible default ZIP archive format; download
extracts it and fails on digest mismatch, followed by firmware SHA256 validation.
The release job alone has contents-write permission and publishes only after a
successful build. Existing releases/tags are preserved.

A weekly read-only stable-version check highlights newer upstream releases for
review. Dependabot opens weekly Actions update PRs against master; it does not
automatically merge updates. Firmware versions remain reviewed fixed commits.
