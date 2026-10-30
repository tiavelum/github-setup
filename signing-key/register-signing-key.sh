#!/bin/bash
# register-signing-key.sh — register the git signing key on GitHub.
#
# git signs with the key gitconfig names. GitHub shows a commit as verified
# only when that key is registered on the account as a signing key, which
# is separate from its registration for authentication by gh auth login.
#
# Safe to re-run: a key that is already registered is left alone.

set -e

# The key path is read from git, so gitconfig stays its only owner.
key_file="$(git config --type=path user.signingkey 2>/dev/null || true)"
if [ -z "$key_file" ]; then
  echo "!! no user.signingkey in the git config — run ~/vc/mac-config/install.sh first" >&2
  exit 1
fi
if [ ! -f "$key_file" ]; then
  echo "!! $key_file missing — run gh auth login and let it generate an SSH key" >&2
  exit 1
fi

if ! auth_status="$(gh auth status -h github.com 2>&1)"; then
  echo "!! gh is not authenticated — run: gh auth login -s admin:ssh_signing_key" >&2
  exit 1
fi

# A plain gh auth login does not grant the scope; add it in place rather
# than stopping, since the browser confirmation is the only step left.
scope=admin:ssh_signing_key
if ! printf '%s\n' "$auth_status" | grep -q "'$scope'"; then
  if [ ! -t 0 ]; then
    echo "!! gh lacks the $scope scope — run: gh auth refresh -h github.com -s $scope" >&2
    exit 1
  fi
  echo "    gh lacks the $scope scope; adding it (confirm in the browser)"
  gh auth refresh -h github.com -s "$scope"
fi

# GitHub stores a key as its type and body, without the comment.
local_key="$(awk '{print $1" "$2}' "$key_file")"

registered_keys() {
  gh api --paginate user/ssh_signing_keys --jq '.[].key'
}

if ! registered="$(registered_keys 2>&1)"; then
  cat >&2 <<EOF
!! gh cannot read the account's signing keys:
   $registered
   If this names a missing scope, run this, confirm in the browser, then
   run this script again:

     gh auth refresh -h github.com -s $scope

EOF
  exit 1
fi

if printf '%s\n' "$registered" | grep -qxF "$local_key"; then
  echo "    signing key already registered on GitHub: $key_file"
  exit 0
fi

title="$(scutil --get ComputerName 2>/dev/null || hostname) signing"
gh ssh-key add "$key_file" --type signing --title "$title"

# Verify the effect: the key is now in the account's list.
if registered_keys 2>/dev/null | grep -qxF "$local_key"; then
  echo "    signing key registered on GitHub as \"$title\""
else
  echo "!! gh ssh-key add reported no error, but the key is not in the account's signing keys" >&2
  exit 1
fi
