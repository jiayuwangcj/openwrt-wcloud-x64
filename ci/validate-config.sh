#!/usr/bin/env bash
set -euo pipefail
[[ $# == 2 ]] || { echo 'usage: validate-config.sh SEED RESOLVED' >&2; exit 2; }
seed=$1
resolved=$2
failed=0
while IFS= read -r setting; do
    [[ $setting == CONFIG_*=* ]] || continue
    if ! grep -Fxq -- "$setting" "$resolved"; then
        printf 'CONFIG_REQUIRED_MISSING: %s\n' "$setting" >&2
        failed=1
    fi
done < "$seed"
# These image formats are deliberately disabled, even if upstream defaults change.
for disabled in TARGET_ROOTFS_INITRAMFS TARGET_ROOTFS_TARGZ TARGET_ROOTFS_EXT4FS GRUB_EFI_IMAGES; do
    if grep -Eq "^CONFIG_${disabled}=[ym]$" "$resolved"; then
        printf 'CONFIG_IMAGE_FORMAT_FORBIDDEN: %s\n' "$disabled" >&2
        failed=1
    fi
done
for forbidden in wireguard-go dropbear ip-tiny; do
    if grep -Eq "^CONFIG_PACKAGE_${forbidden}=[ym]$" "$resolved"; then
        printf 'CONFIG_FORBIDDEN_SELECTED: %s\n' "$forbidden" >&2
        failed=1
    fi
done
(( failed == 0 )) || exit 1
printf 'Required target, images and packages verified.\n'
