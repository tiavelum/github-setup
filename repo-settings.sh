#!/usr/bin/env bash
# repo-settings.sh -- give every repository of a GitHub account the same
# merge settings, branch and tag rulesets, and secret scanning.
#
#   ./repo-settings.sh                 report every repository that differs
#   ./repo-settings.sh --apply         set the values where they differ
#   ./repo-settings.sh [--apply] owner/name ...   only these repositories
#
# The values are repo-settings.json next to this script. Archived
# repositories and forks are printed as skipped and left unchanged. Exits
# 1 when a repository still differs or could not be read, so the check
# can gate.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$SCRIPT_DIR/repo-settings.json"
APPLY=0
repos=()

for arg in "$@"; do
  case "$arg" in
  --apply) APPLY=1 ;;
  -h | --help)
    sed -n '2,13p' "$0"
    exit 0
    ;;
  -*)
    echo "unknown option: $arg" >&2
    exit 2
    ;;
  *) repos+=("$arg") ;;
  esac
done

for tool in gh jq; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "!! $tool not found -- install it" >&2
    exit 2
  }
done
gh auth status >/dev/null 2>&1 || {
  echo "!! gh is not logged in -- run gh auth login" >&2
  exit 2
}
[ -f "$SETTINGS" ] || {
  echo "!! $SETTINGS missing" >&2
  exit 2
}
if ! repository="$(jq -ce '.repository' "$SETTINGS")" ||
  ! security="$(jq -ce '.security_and_analysis' "$SETTINGS")" ||
  ! rulesets="$(jq -ce '.rulesets' "$SETTINGS")"; then
  echo "!! $SETTINGS needs repository, security_and_analysis and rulesets" >&2
  exit 2
fi
ruleset_count="$(jq 'length' <<<"$rulesets")"

if [ "${#repos[@]}" -eq 0 ]; then
  owner="$(gh api user --jq .login)" || {
    echo "!! could not read the account" >&2
    exit 2
  }
  while IFS= read -r r; do repos+=("$r"); done < <(
    gh repo list "$owner" --limit 1000 \
      --json nameWithOwner --jq '.[].nameWithOwner'
  )
fi

# The *_differences functions print one line per field that differs,
# "<field> <current> -> <wanted>", and nothing when every field matches.

# $1: the repository as GET repos/<owner>/<name> returns it.
merge_differences() {
  jq -r --argjson want "$repository" '. as $r | $want | to_entries[]
    | select($r[.key] != .value)
    | "\(.key) \($r[.key]) -> \(.value)"' <<<"$1"
}

# Secret scanning is compared on a public repository only: a repository
# of a personal account can enable it nowhere else.
security_differences() {
  jq -r --argjson want "$security" '. as $r
    | select($r.visibility == "public") | $want | to_entries[]
    | $r.security_and_analysis[.key].status as $cur
    | select($cur != .value.status)
    | "\(.key) \($cur) -> \(.value.status)"' <<<"$1"
}

# $1: a ruleset of repo-settings.json; $2: the ruleset as
# GET repos/<owner>/<name>/rulesets/<id> returns it. A rule parameter
# that repo-settings.json leaves out is not compared.
ruleset_differences() {
  jq -r --argjson want "$1" '
    def refs: {include: ((.include // []) | sort),
               exclude: ((.exclude // []) | sort)};
    def actors: map({actor_id, actor_type,
                     bypass_mode: (.bypass_mode // "always")})
      | sort_by(.actor_type, .actor_id);
    . as $cur | "ruleset \($want.name):" as $p
    | (("target", "enforcement") as $k
        | select($cur[$k] != $want[$k])
        | "\($p) \($k) \($cur[$k]) -> \($want[$k])"),
      ((($cur.conditions.ref_name // {}) | refs) as $c
        | ($want.conditions.ref_name | refs) as $w
        | select($c != $w)
        | "\($p) refs \($c | tojson) -> \($w | tojson)"),
      ((($cur.bypass_actors // []) | actors) as $c
        | (($want.bypass_actors // []) | actors) as $w
        | select($c != $w)
        | "\($p) bypass_actors \($c | tojson) -> \($w | tojson)"),
      ($want.rules[] as $wr
        | ([($cur.rules // [])[] | select(.type == $wr.type)] | first) as $cr
        | if $cr == null then "\($p) rule \($wr.type) missing"
          else ($wr.parameters // {}) | to_entries[]
            | select($cr.parameters[.key] != .value)
            | "\($p) \($wr.type).\(.key) \($cr.parameters[.key]) -> \(.value)"
          end),
      (($cur.rules // [])[] | .type as $t
        | select(any($want.rules[]; .type == $t) | not)
        | "\($p) rule \($t) is not in repo-settings.json")' <<<"$2"
}

# Succeeds when branch $2 of repository $1 exists; fails with status 1
# when it does not and with status 2 when it cannot be read.
branch_exists() {
  local err
  err="$(gh api "repos/$1/branches/$2" --silent 2>&1)" && return 0
  case "$err" in *"HTTP 404"*) return 1 ;; esac
  printf '%s\n' "$err" >&2
  return 2
}

# The rulesets are compared on a public repository only, since a private
# repository gets them only on a paid plan, and once the default branch
# exists: before the first commit there is no branch for them to protect
# and nothing to tag. $1: the repository; $2: its JSON. With $3 = apply,
# each ruleset that differs is set instead of printed.
rulesets_step() {
  local repo="$1" branch status list i want id current lines
  [ "$(jq -r '.visibility' <<<"$2")" = public ] || return 0
  branch="$(jq -r '.default_branch' <<<"$2")"
  branch_exists "$repo" "$branch"
  status=$?
  [ "$status" -eq 1 ] && return 0
  [ "$status" -eq 0 ] || return 1
  list="$(gh api "repos/$repo/rulesets?includes_parents=false&per_page=100")" ||
    return 1
  i=0
  while [ "$i" -lt "$ruleset_count" ]; do
    want="$(jq -c --argjson i "$i" '.[$i]' <<<"$rulesets")"
    id="$(jq -r --argjson w "$want" 'first(.[]
      | select(.name == $w.name and .target == $w.target) | .id) // empty' \
      <<<"$list")" || return 1
    if [ -z "$id" ]; then
      lines="ruleset $(jq -r '.name' <<<"$want"): missing"
    else
      current="$(gh api "repos/$repo/rulesets/$id")" || return 1
      lines="$(ruleset_differences "$want" "$current")" || return 1
    fi
    if [ -n "$lines" ]; then
      if [ "${3:-}" != apply ]; then
        printf '%s\n' "$lines"
      elif [ -z "$id" ]; then
        gh api -X POST "repos/$repo/rulesets" --input - <<<"$want" \
          >/dev/null || return 1
      else
        gh api -X PUT "repos/$repo/rulesets/$id" --input - <<<"$want" \
          >/dev/null || return 1
      fi
    fi
    i=$((i + 1))
  done
}

# Prints why repository JSON $1 is skipped, and nothing when it is not.
skip_reason() {
  jq -r 'if .archived then "archived" elif .fork then "fork"
    else empty end' <<<"$1"
}

# $1: the repository; $2: its JSON, read anew when left out.
differences() {
  local repo_json="${2:-}"
  [ -n "$repo_json" ] || repo_json="$(gh api "repos/$1")" || return 1
  merge_differences "$repo_json" || return 1
  security_differences "$repo_json" || return 1
  rulesets_step "$1" "$repo_json" || echo "rulesets: could not be read"
}

# $1: the repository; $2: its JSON.
apply_settings() {
  local repo_json="$2"
  if [ -n "$(merge_differences "$repo_json")" ]; then
    gh api -X PATCH "repos/$1" --input - <<<"$repository" >/dev/null ||
      return 1
  fi
  if [ -n "$(security_differences "$repo_json")" ]; then
    jq -c '{security_and_analysis: .}' <<<"$security" |
      gh api -X PATCH "repos/$1" --input - >/dev/null || return 1
  fi
  rulesets_step "$1" "$repo_json" apply || true
}

differing=0
unreadable=0
checked=0
skipped=0
for repo in "${repos[@]}"; do
  if ! repo_json="$(gh api "repos/$repo" 2>&1)" ||
    ! reason="$(skip_reason "$repo_json" 2>&1)"; then
    echo "!! $repo: could not read its settings -- ${repo_json##*$'\n'}" >&2
    unreadable=$((unreadable + 1))
    continue
  fi
  if [ -n "$reason" ]; then
    echo "skipped $repo ($reason)"
    skipped=$((skipped + 1))
    continue
  fi
  if ! diff_lines="$(differences "$repo" "$repo_json" 2>&1)"; then
    echo "!! $repo: could not read its settings -- ${diff_lines##*$'\n'}" >&2
    unreadable=$((unreadable + 1))
    continue
  fi
  if [ -z "$diff_lines" ]; then
    echo "  ok  $repo"
    checked=$((checked + 1))
    continue
  fi
  if [ "$APPLY" -eq 1 ]; then
    if err="$(apply_settings "$repo" "$repo_json" 2>&1)" &&
      after="$(differences "$repo" 2>/dev/null)" && [ -z "$after" ]; then
      echo "  set $repo"
      checked=$((checked + 1))
      printf '%s\n' "$diff_lines" | sed 's/^/        /'
    else
      echo "!! $repo: setting the values failed${err:+ -- ${err##*$'\n'}}" >&2
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
if [ "$checked" -eq 0 ]; then
  echo "==> no repository checked; $skipped skipped"
  exit 0
fi
echo "==> every repository checked has the settings of repo-settings.json"
