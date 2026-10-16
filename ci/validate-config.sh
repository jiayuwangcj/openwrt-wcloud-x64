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
for forbidden in kmod-wireguard wireguard-tools dropbear ip-tiny; do
    if grep -Eq "^CONFIG_PACKAGE_${forbidden}=[ym]$" "$resolved"; then
        printf 'CONFIG_FORBIDDEN_SELECTED: %s\n' "$forbidden" >&2
        failed=1
    fi
done
(( failed == 0 )) || exit 1
printf 'Required target, images and packages verified.\n'
