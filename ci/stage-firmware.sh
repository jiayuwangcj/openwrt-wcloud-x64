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
mkdir -p "$output_dir"
find "$source_dir" -maxdepth 1 -type f -exec cp -t "$output_dir" -- {} +
(
    cd "$output_dir"
    sha256sum -c --ignore-missing sha256sums
)
