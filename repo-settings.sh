#!/usr/bin/env bash
# repo-settings.sh -- give every repository of a GitHub account the same
# merge and branch settings.
#
#   ./repo-settings.sh                 report every repository that differs
#   ./repo-settings.sh --apply         set the values where they differ
#   ./repo-settings.sh [--apply] owner/name ...   only these repositories
#
# The values are repo-settings.json next to this script. Archived
# repositories and forks are skipped. Exits 1 when a repository still
# differs, so the check can gate.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$SCRIPT_DIR/repo-settings.json"
APPLY=0
repos=()

for arg in "$@"; do
  case "$arg" in
  --apply) APPLY=1 ;;
  -h | --help)
    sed -n '2,12p' "$0"
    exit 0
    ;;
  -*)
    echo "unknown option: $arg" >&2
    exit 2
    ;;
  *) repos+=("$arg") ;;
  esac
done

command -v gh >/dev/null 2>&1 || {
  echo "!! gh not found -- install it and run gh auth login" >&2
  exit 2
}
gh auth status >/dev/null 2>&1 || {
  echo "!! gh is not logged in -- run gh auth login" >&2
  exit 2
}
[ -f "$SETTINGS" ] || {
  echo "!! $SETTINGS missing" >&2
  exit 2
}
desired="$(tr -d '\n' <"$SETTINGS")"

if [ "${#repos[@]}" -eq 0 ]; then
  owner="$(gh api user --jq .login)" || {
    echo "!! could not read the account" >&2
    exit 2
  }
  while IFS= read -r r; do repos+=("$r"); done < <(
    gh repo list "$owner" --limit 1000 --no-archived --source \
      --json nameWithOwner --jq '.[].nameWithOwner'
  )
fi

# One line per field that differs: "<field> <current> -> <wanted>".
differences() {
  gh api "repos/$1" --jq ". as \$r | $desired | to_entries[]
    | select(\$r[.key] != .value)
    | \"\(.key) \(\$r[.key]) -> \(.value)\""
}

differing=0
unreadable=0
for repo in "${repos[@]}"; do
  if ! diff_lines="$(differences "$repo" 2>&1)"; then
    echo "!! $repo: could not read its settings -- ${diff_lines%%$'\n'*}" >&2
    unreadable=$((unreadable + 1))
    continue
  fi
  if [ -z "$diff_lines" ]; then
    echo "  ok  $repo"
    continue
  fi
  if [ "$APPLY" -eq 1 ]; then
    if gh api -X PATCH "repos/$repo" --input "$SETTINGS" >/dev/null 2>&1 &&
      [ -z "$(differences "$repo")" ]; then
      echo "  set $repo"
      printf '%s\n' "$diff_lines" | sed 's/^/        /'
    else
      echo "!! $repo: setting the values failed" >&2
      differing=$((differing + 1))
    fi
  else
    echo "diff  $repo"
    printf '%s\n' "$diff_lines" | sed 's/^/        /'
    differing=$((differing + 1))
  fi
done

[ "$unreadable" -gt 0 ] && echo "==> $unreadable repository/ies could not be checked"
if [ "$differing" -gt 0 ]; then
  if [ "$APPLY" -eq 1 ]; then
    echo "==> $differing repository/ies could not be set"
  else
    echo "==> $differing repository/ies differ; run with --apply to set them"
  fi
  exit 1
fi
[ "$unreadable" -gt 0 ] && exit 1
echo "==> every repository has the settings of repo-settings.json"
