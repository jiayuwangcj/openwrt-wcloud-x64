#!/usr/bin/env bash
set -euo pipefail
[[ $# == 2 ]] || { echo 'usage: stage-firmware.sh OPENWRT OUTPUT' >&2; exit 2; }
source_dir=$1/bin/targets/x86/64
output_dir=$2
[[ -d $source_dir && ! -e $output_dir ]] || {
    echo 'FIRMWARE_STAGE_PATH_INVALID: missing source or existing output' >&2; exit 1;
}
for required in '*squashfs-combined.img.gz' '*squashfs-combined-efi.img.gz' '*ext4-combined.img.gz'; do
    compgen -G "$source_dir/$required" >/dev/null || {
        printf 'FIRMWARE_IMAGE_MISSING: %s\n' "$required" >&2; exit 1;
    }
done
[[ -s $source_dir/sha256sums ]] || { echo 'FIRMWARE_CHECKSUMS_MISSING' >&2; exit 1; }
shopt -s nullglob
manifests=("$source_dir/"*.manifest)
(( ${#manifests[@]} > 0 )) || { echo 'FIRMWARE_MANIFEST_MISSING' >&2; exit 1; }
for manifest in "${manifests[@]}"; do
    for required in kmod-wireguard wireguard-tools luci-proto-wireguard; do
        grep -Eq "^${required}([[:space:]]|$)" "$manifest" || {
            printf 'FIRMWARE_REQUIRED_PACKAGE_MISSING: %s in %s\n' "$required" "$manifest" >&2; exit 1;
        }
    done
done
mkdir -p "$output_dir"
find "$source_dir" -maxdepth 1 -type f -exec cp -t "$output_dir" -- {} +
(
    cd "$output_dir"
    sha256sum -c --ignore-missing sha256sums
)
