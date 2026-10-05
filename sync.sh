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
    gh api -X PUT "repos/$repo/rulesets/$id" --input "$file" --silent
    echo "updated    $name"
  else
    gh api -X POST "repos/$repo/rulesets" --input "$file" --silent
    echo "created    $name"
  fi
done

# Flag rulesets that don't come from this repo (e.g. older hand-made ones).
# They keep applying alongside these, so review and delete them manually.
managed=$(for file in "$dir"/*.json; do name_of "$file"; done)
while IFS=$'\t' read -r _ name url; do
  [ -n "$name" ] || continue
  grep -qxF "$name" <<<"$managed" || echo "unmanaged  $name  $url"
done <<<"$existing"
