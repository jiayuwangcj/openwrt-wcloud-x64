#!/usr/bin/env bash
set -euo pipefail
[[ $# == 2 ]] || { echo 'usage: compile-firmware.sh SOURCE_DIR DIAGNOSTICS_DIR' >&2; exit 2; }
[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted ]] || {
    echo 'FIRMWARE_BUILD_REQUIRES_GITHUB_HOSTED_RUNNER' >&2; exit 1;
}
source_dir=$(realpath "$1")
diagnostics_dir=$(realpath "$2")
cd "$source_dir"
echo '::group::Download verified package sources'
make download -j8 V=s 2>&1 | tee "$diagnostics_dir/download.log"
echo '::endgroup::'
echo '::group::Compile firmware (parallel, then serial retry if needed)'
make -j"$(nproc)" V=s 2>&1 | tee "$diagnostics_dir/build.log" || \
    make -j1 V=s 2>&1 | tee "$diagnostics_dir/build-retry.log"
echo '::endgroup::'
