#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/SukkaLab/ruleset.skk.moe.git}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-master}"
SYNC_STATE_FILE="${SYNC_STATE_FILE:-.upstream-sync}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

echo "Fetching upstream ${UPSTREAM_REPO} (${UPSTREAM_BRANCH})..."
git clone --depth 1 --branch "$UPSTREAM_BRANCH" "$UPSTREAM_REPO" "$tmp_dir/upstream"

upstream_commit="$(git -C "$tmp_dir/upstream" rev-parse HEAD)"
previous_commit=""
if [[ -f "$SYNC_STATE_FILE" ]]; then
  previous_commit="$(cat "$SYNC_STATE_FILE")"
fi

if [[ "$previous_commit" == "$upstream_commit" ]]; then
  echo "Upstream already synced at ${upstream_commit}."
  exit 0
fi

echo "Syncing upstream commit ${upstream_commit}..."

rsync -a --delete \
  --exclude ".git/" \
  --exclude ".github/" \
  --exclude "scripts/" \
  --exclude "$SYNC_STATE_FILE" \
  --exclude "vendor-rules.conf" \
  --exclude "CNAME" \
  --exclude "List/add-on/" \
  --exclude "Clash/add-on/" \
  --exclude "sing-box/add-on/" \
  --exclude "Surfboard/add-on/" \
  --exclude "Modules/add-on/" \
  "$tmp_dir/upstream/" "$repo_root/"

printf '%s\n' "$upstream_commit" > "$SYNC_STATE_FILE"

echo "SYNCED_UPSTREAM_COMMIT=${upstream_commit}" >> "${GITHUB_ENV:-/dev/null}"

if [[ -z "$(git status --porcelain)" ]]; then
  echo "No file changes after syncing upstream."
  exit 0
fi

echo "Upstream changes synced into working tree."
