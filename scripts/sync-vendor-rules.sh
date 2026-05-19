#!/usr/bin/env bash
set -euo pipefail

MANIFEST_FILE="${MANIFEST_FILE:-vendor-rules.conf}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "Manifest file not found: ${MANIFEST_FILE}" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

changed=0

while read -r output url extra; do
  [[ -z "${output:-}" || "${output:0:1}" == "#" ]] && continue

  if [[ -z "${url:-}" || -n "${extra:-}" ]]; then
    echo "Invalid manifest line: ${output} ${url:-} ${extra:-}" >&2
    exit 1
  fi

  case "$output" in
    List/add-on/*.conf) ;;
    *)
      echo "Refusing to write outside List/add-on/*.conf: ${output}" >&2
      exit 1
      ;;
  esac

  target_dir="$(dirname "$output")"
  tmp_file="${tmp_dir}/$(basename "$output")"

  echo "Fetching ${url} -> ${output}"
  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 60 \
    "$url" -o "$tmp_file"

  if [[ ! -s "$tmp_file" ]]; then
    echo "Downloaded file is empty: ${url}" >&2
    exit 1
  fi

  if LC_ALL=C grep -qiE '^[[:space:]]*<(html|!doctype)' "$tmp_file"; then
    echo "Downloaded file looks like HTML, not a ruleset: ${url}" >&2
    exit 1
  fi

  mkdir -p "$target_dir"
  if [[ -f "$output" ]] && cmp -s "$tmp_file" "$output"; then
    echo "No change: ${output}"
    continue
  fi

  mv "$tmp_file" "$output"
  changed=1
  echo "Updated: ${output}"
done < "$MANIFEST_FILE"

if [[ "$changed" -eq 1 ]]; then
  echo "VENDOR_RULES_CHANGED=true" >> "${GITHUB_ENV:-/dev/null}"
  echo "Vendor rules updated."
else
  echo "Vendor rules already up to date."
fi
