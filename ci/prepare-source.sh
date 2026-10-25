#!/usr/bin/env bash
# Shared by configuration checks and firmware builds; does not compile firmware.
set -euo pipefail
[[ $# == 2 ]] || { echo 'usage: prepare-source.sh SOURCE_DIR DIAGNOSTICS_DIR' >&2; exit 2; }
: "${OPENWRT_REF:?Missing reviewed release tag}"
: "${OPENWRT_COMMIT:?Missing reviewed source commit}"
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
source_dir=$(realpath -m "$1")
diagnostics_dir=$(realpath -m "$2")
[[ ! -e $source_dir ]] || { echo 'SOURCE_PATH_ALREADY_EXISTS' >&2; exit 1; }
mkdir -p "$diagnostics_dir"

echo '::group::Clone and verify stable OpenWrt source'
git clone --depth 1 --branch "$OPENWRT_REF" \
    https://github.com/openwrt/openwrt.git "$source_dir"
cd "$source_dir"
[[ $(git rev-parse HEAD) == "$OPENWRT_COMMIT" ]] || {
    echo 'SOURCE_COMMIT_MISMATCH' >&2; exit 1;
}
git rev-parse HEAD > "$diagnostics_dir/openwrt-commit"
cp feeds.conf.default "$diagnostics_dir/feeds.conf.pinned"
echo '::endgroup::'

echo '::group::Install release-pinned feeds'
bash "$repo_dir/diy-part1.sh"
cmp feeds.conf.default "$diagnostics_dir/feeds.conf.pinned" || {
    echo 'RELEASE_FEEDS_CHANGED: keep the reviewed release pins' >&2; exit 1;
}
./scripts/feeds update -a 2>&1 | tee "$diagnostics_dir/feeds-update.log"
./scripts/feeds install -a 2>&1 | tee "$diagnostics_dir/feeds-install.log"
# Derive names from the upstream release instead of maintaining a second list.
while read -r kind name url _; do
    [[ -n $kind && $kind != \#* ]] || continue
    [[ $kind == src-git || $kind == src-git-full ]] &&
        [[ $url =~ \^([0-9a-f]{40})$ ]] || {
        echo "FEED_NOT_COMMIT_PINNED: $name" >&2; exit 1;
    }
    expected=${BASH_REMATCH[1]}
    actual=$(git -C "feeds/$name" rev-parse HEAD)
    [[ $actual == "$expected" ]] || { echo "FEED_COMMIT_MISMATCH: $name" >&2; exit 1; }
    printf '%s %s\n' "$name" "$actual"
done < feeds.conf.default > "$diagnostics_dir/feed-commits"
echo '::endgroup::'

echo '::group::Resolve and validate requested packages'
cp "$repo_dir/config" .config
if [[ -d $repo_dir/files ]]; then
    mkdir -p files
    cp -a "$repo_dir/files/." files/
fi
bash "$repo_dir/diy-part2.sh"
make defconfig 2>&1 | tee "$diagnostics_dir/defconfig.log"
cp .config "$diagnostics_dir/resolved.config"
./scripts/diffconfig.sh > "$diagnostics_dir/diffconfig"
bash "$repo_dir/ci/validate-config.sh" "$repo_dir/config" .config
printf 'Configuration commit: %s\nOpenWrt: %s (%s)\n' \
    "${GITHUB_SHA:-$(git -C "$repo_dir" rev-parse HEAD)}" "$OPENWRT_REF" "$OPENWRT_COMMIT" \
    > "$diagnostics_dir/build-provenance.txt"
echo '::endgroup::'
