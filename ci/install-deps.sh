#!/usr/bin/env bash
# Provision only disposable GitHub-hosted Ubuntu runners.
set -euo pipefail
[[ $# == 1 && ( $1 == check || $1 == build ) ]] || {
    echo 'usage: install-deps.sh check|build' >&2; exit 2;
}
[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted ]] || {
    echo 'DEPENDENCIES_REQUIRE_GITHUB_HOSTED_RUNNER' >&2; exit 1;
}
packages=(
    build-essential flex bison gawk gettext git libncurses-dev libssl-dev
    python3 python3-setuptools rsync unzip zlib1g-dev file ca-certificates
)
if [[ $1 == build ]]; then
    # Reclaim SDK space only on the disposable firmware build runner.
    sudo rm -rf -- /usr/local/lib/android /usr/share/dotnet /opt/ghc
    packages+=(
        clang gcc-multilib g++-multilib python3-pyelftools swig wget curl
        patch diffutils findutils perl time jq xz-utils zstd bzip2 cpio
        squashfs-tools libelf-dev libzstd-dev
    )
fi
sudo apt-get update
sudo apt-get install -y --no-install-recommends "${packages[@]}"
