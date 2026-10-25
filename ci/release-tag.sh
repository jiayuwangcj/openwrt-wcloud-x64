#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 && ( $1 == prepare || $1 == verify ) ]] || {
    echo 'usage: release-tag.sh prepare|verify' >&2; exit 2;
}
for required in GH_TOKEN GITHUB_REPOSITORY GITHUB_SHA GITHUB_RUN_ID OPENWRT_REF; do
    [[ -n ${!required:-} ]] || { echo "RELEASE_ENV_MISSING: $required" >&2; exit 1; }
done
[[ $GITHUB_SHA =~ ^[0-9a-f]{40}$ && $GITHUB_RUN_ID =~ ^[0-9]+$ && $OPENWRT_REF =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo 'RELEASE_ID_INVALID' >&2; exit 1;
}
# Keep the same tag when only a failed publication job is retried.
tag="${OPENWRT_REF}-x86-64-${GITHUB_RUN_ID}"
query=".[] | select(.ref == \"refs/tags/$tag\") | \"\(.object.type) \(.object.sha)\""
target=$(gh api "repos/$GITHUB_REPOSITORY/git/matching-refs/tags/$tag" --jq "$query")
if [[ -z $target && $1 == prepare ]]; then
    # Reserve the exact source before the long build, while its workflows are current.
    # Do not use a moving branch or force-update an existing tag on failure.
    target=$(gh api --method POST "repos/$GITHUB_REPOSITORY/git/refs" \
        -f "ref=refs/tags/$tag" -f "sha=$GITHUB_SHA" \
        --jq '"\(.object.type) \(.object.sha)"')
fi
[[ $target == "commit $GITHUB_SHA" ]] || {
    echo "RELEASE_TAG_MISSING_OR_MISMATCHED: $tag" >&2; exit 1;
}
printf '%s\n' "$tag"
