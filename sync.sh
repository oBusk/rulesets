#!/usr/bin/env bash
# Creates or updates rulesets in a repo, matching existing ones by name.
# Needs gh (authenticated) and jq.
#
#   ./sync.sh OWNER/REPO                    # base + tag protection, plus any
#                                           # opt-in ruleset the repo already has
#   ./sync.sh OWNER/REPO require-pr.json    # only the given file(s)
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 OWNER/REPO [ruleset.json ...]" >&2
  exit 1
fi

repo=$1
shift
dir=$(cd "$(dirname "$0")" && pwd)

existing=$(gh api "repos/$repo/rulesets" --paginate --jq '.[] | [.id, .name, ._links.html.href] | @tsv')

# jq on Windows writes CRLF, so strip \r before comparing names.
name_of() { jq -r .name "$1" | tr -d '\r'; }
id_of() { awk -F'\t' -v name="$1" '$2 == name { print $1; exit }' <<<"$existing"; }

# Name pattern rules (*_pattern) are GitHub Enterprise only. The UI import drops
# them silently but the API rejects the whole ruleset, so retry without them.
apply() {
  local method=$1 path=$2 file=$3 out
  note=""
  # No --silent here: gh only prints the error body (with the rule name) without it.
  if out=$(gh api -X "$method" "$path" --input "$file" 2>&1); then
    return
  fi
  if ! grep -q "Invalid rule '[a-z_]*_pattern'" <<<"$out"; then
    echo "$out" >&2
    return 1
  fi
  jq '.rules |= map(select(.type | endswith("_pattern") | not))' "$file" |
    gh api -X "$method" "$path" --input - --silent
  note="  (without name pattern rules, not available on this plan)"
}

if [ $# -gt 0 ]; then
  files=("$@")
else
  files=("$dir/main-branch-base.json" "$dir/tag-protection.json")
  for file in "$dir"/*.json; do
    case $file in "${files[0]}" | "${files[1]}") continue ;; esac
    if [ -n "$(id_of "$(name_of "$file")")" ]; then
      files+=("$file")
    fi
  done
fi

for file in "${files[@]}"; do
  name=$(name_of "$file")
  id=$(id_of "$name")
  if [ -n "$id" ]; then
    apply PUT "repos/$repo/rulesets/$id" "$file"
    echo "updated    $name$note"
  else
    apply POST "repos/$repo/rulesets" "$file"
    echo "created    $name$note"
  fi
done

# Flag rulesets that don't come from this repo (e.g. older hand-made ones).
# They keep applying alongside these, so review and delete them manually.
managed=$(for file in "$dir"/*.json; do name_of "$file"; done)
while IFS=$'\t' read -r _ name url; do
  [ -n "$name" ] || continue
  grep -qxF "$name" <<<"$managed" || echo "unmanaged  $name  $url"
done <<<"$existing"
