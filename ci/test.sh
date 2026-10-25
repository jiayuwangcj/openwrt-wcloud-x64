#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture_dir=$(mktemp -d)
trap 'rm -r -- "$fixture_dir"' EXIT

bash -n ci/*.sh diy-part*.sh
bash ci/validate-config.sh config config
sed '/^CONFIG_PACKAGE_zerotier=y$/d' config > "$fixture_dir/missing"
if bash ci/validate-config.sh config "$fixture_dir/missing" > "$fixture_dir/missing.log" 2>&1; then
    echo 'TEST_FAILED: missing package was accepted' >&2; exit 1
fi
grep -q 'CONFIG_REQUIRED_MISSING: CONFIG_PACKAGE_zerotier=y' "$fixture_dir/missing.log"
for required in kmod-wireguard wireguard-tools luci-proto-wireguard luci-app-sqm sqm-scripts kmod-sched-cake kmod-ifb tc-full smartdns; do
    sed "/^CONFIG_PACKAGE_${required}=y$/d" config > "$fixture_dir/missing-wireguard"
    if bash ci/validate-config.sh config "$fixture_dir/missing-wireguard" > "$fixture_dir/missing-wireguard.log" 2>&1; then
        echo "TEST_FAILED: missing required package $required was accepted" >&2; exit 1
    fi
    grep -q "CONFIG_REQUIRED_MISSING: CONFIG_PACKAGE_${required}=y" "$fixture_dir/missing-wireguard.log"
done
for forbidden in wireguard-go dropbear ip-tiny; do
    cp config "$fixture_dir/forbidden"
    printf 'CONFIG_PACKAGE_%s=m\n' "$forbidden" >> "$fixture_dir/forbidden"
    if bash ci/validate-config.sh config "$fixture_dir/forbidden" > "$fixture_dir/forbidden.log" 2>&1; then
        echo "TEST_FAILED: forbidden package $forbidden was accepted" >&2; exit 1
    fi
    grep -q "CONFIG_FORBIDDEN_SELECTED: $forbidden" "$fixture_dir/forbidden.log"
done

fixture_images=$fixture_dir/source/bin/targets/x86/64
mkdir -p "$fixture_images/packages"
for image in squashfs-combined squashfs-combined-efi ext4-combined; do
    printf 'test-image-%s\n' "$image" > "$fixture_images/openwrt-x86-64-generic-$image.img.gz"
done
printf 'do-not-upload\n' > "$fixture_images/packages/private.apk"
while IFS= read -r required; do
    printf '%s - test-version\n' "$required" >> "$fixture_images/openwrt-test.manifest"
done < <(sed -n 's/^CONFIG_PACKAGE_\(.*\)=y$/\1/p' config)
(
    cd "$fixture_images"
    sha256sum ./*.img.gz > sha256sums
)
bash ci/stage-firmware.sh "$fixture_dir/source" "$fixture_dir/output"
test ! -e "$fixture_dir/output/packages"
if bash ci/stage-firmware.sh "$fixture_dir/source" "$fixture_dir/output" > /dev/null 2>&1; then
    echo 'TEST_FAILED: existing output was overwritten' >&2; exit 1
fi
cp "$fixture_images/openwrt-test.manifest" "$fixture_dir/complete.manifest"
for required in kmod-wireguard luci-app-sqm sqm-scripts kmod-sched-cake kmod-ifb tc-full smartdns; do
    sed "/^${required} /d" "$fixture_dir/complete.manifest" > "$fixture_images/openwrt-test.manifest"
    if bash ci/stage-firmware.sh "$fixture_dir/source" "$fixture_dir/missing-$required-output" > "$fixture_dir/missing-manifest.log" 2>&1; then
        echo "TEST_FAILED: missing $required in image manifest was accepted" >&2; exit 1
    fi
    grep -q "FIRMWARE_REQUIRED_PACKAGE_MISSING: $required in " "$fixture_dir/missing-manifest.log"
done
cp "$fixture_dir/complete.manifest" "$fixture_images/openwrt-test.manifest"
printf 'corrupted\n' >> "$fixture_images/openwrt-x86-64-generic-ext4-combined.img.gz"
if bash ci/stage-firmware.sh "$fixture_dir/source" "$fixture_dir/corrupt-output" > /dev/null 2>&1; then
    echo 'TEST_FAILED: corrupted firmware was accepted' >&2; exit 1
fi
rm -- "$fixture_images/openwrt-x86-64-generic-squashfs-combined-efi.img.gz"
if bash ci/stage-firmware.sh "$fixture_dir/source" "$fixture_dir/incomplete-output" > /dev/null 2>&1; then
    echo 'TEST_FAILED: incomplete firmware was accepted' >&2; exit 1
fi
echo 'Build harness tests passed (temporary fixtures only).'
