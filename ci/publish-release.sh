#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 ]] || { echo 'usage: publish-release.sh FIRMWARE_DIR' >&2; exit 2; }
for required in GH_TOKEN GITHUB_REPOSITORY GITHUB_SHA GITHUB_RUN_ID GITHUB_RUN_ATTEMPT OPENWRT_REF OPENWRT_COMMIT; do
    [[ -n ${!required:-} ]] || { echo "RELEASE_ENV_MISSING: $required" >&2; exit 1; }
done
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$1"
# Confirm the downloaded artifact belongs to this build before publishing.
grep -Fxq "Configuration commit: $GITHUB_SHA" build-provenance.txt
grep -Fxq "OpenWrt: $OPENWRT_REF ($OPENWRT_COMMIT)" build-provenance.txt
release_files=(
    openwrt-x86-64-generic-squashfs-combined.img.gz
    sha256sums
    openwrt-x86-64-generic.manifest
    build-provenance.txt
)
for file in "${release_files[@]}"; do
    [[ -s $file ]] || { echo "RELEASE_FILE_MISSING: $file" >&2; exit 1; }
done
read -r checksum checksum_image < sha256sums
[[ $(wc -l < sha256sums) == 1 && $checksum_image == "${release_files[0]}" ]] || {
    echo 'RELEASE_CHECKSUM_LIST_INVALID' >&2; exit 1;
}
sha256sum -c --strict sha256sums

tag=$(bash "$script_dir/release-tag.sh" verify)
notes=$(mktemp)
trap 'rm -f -- "$notes"' EXIT
cat > "$notes" <<EOF
OpenWrt ${OPENWRT_REF}, x86-64, from pinned source ${OPENWRT_COMMIT}.

Includes standard WireGuard, SQM/CAKE, SmartDNS, script runtimes and diagnostic tools.
Required packages and firmware SHA256 checksums passed CI validation.
BIOS / SquashFS: openwrt-x86-64-generic-squashfs-combined.img.gz (wrt1 and wrt2).
Verify downloads against sha256sums before use.

Configuration commit: ${GITHUB_SHA}
Build: https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}

This image has not been boot-tested on your devices. Private highflow programs
and configuration are not included. Validate major-version upgrades in an isolated VM.
EOF
gh release create "$tag" "${release_files[@]}" \
    --repo "$GITHUB_REPOSITORY" --verify-tag \
    --title "OpenWrt ${OPENWRT_REF} x86-64 (build ${GITHUB_RUN_ID}.${GITHUB_RUN_ATTEMPT})" \
    --notes-file "$notes" --draft
gh release edit "$tag" --repo "$GITHUB_REPOSITORY" --draft=false --latest
printf 'Release: https://github.com/%s/releases/tag/%s\n' \
    "$GITHUB_REPOSITORY" "$tag" >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
