#!/usr/bin/env bash
set -euo pipefail
[[ $# == 2 ]] || { echo 'usage: stage-firmware.sh OPENWRT OUTPUT' >&2; exit 2; }
source_dir=$1/bin/targets/x86/64
output_dir=$2
[[ -d $source_dir && ! -e $output_dir ]] || {
    echo 'FIRMWARE_STAGE_PATH_INVALID: missing source or existing output' >&2; exit 1;
}
image=openwrt-x86-64-generic-squashfs-combined.img.gz
manifest=openwrt-x86-64-generic.manifest
for required in "$image" "$manifest"; do
    [[ -s $source_dir/$required ]] || {
        printf 'FIRMWARE_IMAGE_MISSING: %s\n' "$required" >&2; exit 1;
    }
done
[[ -s $source_dir/sha256sums ]] || { echo 'FIRMWARE_CHECKSUMS_MISSING' >&2; exit 1; }
# Validate every explicitly requested package, including SQM and backup parity.
seed=$(cd "$(dirname "$0")/.." && pwd)/config
mapfile -t required_packages < <(sed -n 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/p' "$seed")
(( ${#required_packages[@]} > 0 )) || { echo 'FIRMWARE_PACKAGE_SEED_EMPTY' >&2; exit 1; }
for required in "${required_packages[@]}"; do
    grep -Eq "^${required}([[:space:]]|$)" "$source_dir/$manifest" || {
        printf 'FIRMWARE_REQUIRED_PACKAGE_MISSING: %s in %s\n' "$required" "$manifest" >&2; exit 1;
    }
done
mkdir -p "$output_dir"
# Explicit allowlist: never upload standalone kernels, rootfs, EFI or ext4 images.
cp -- "$source_dir/$image" "$source_dir/$manifest" "$output_dir/"
awk -v image="$image" '$2 == image || $2 == "./" image || $2 == "*" image {print $1 "  " image}' \
    "$source_dir/sha256sums" > "$output_dir/sha256sums"
[[ $(wc -l < "$output_dir/sha256sums") == 1 ]] || {
    echo 'FIRMWARE_IMAGE_CHECKSUM_MISSING_OR_DUPLICATE' >&2; exit 1;
}
(
    cd "$output_dir"
    sha256sum -c --strict sha256sums
)
