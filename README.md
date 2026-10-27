# github-setup

Settings for a GitHub account. It gives every repository of the account the
same merge and branch settings and reports the repositories that differ,
and it registers a Mac's git signing key on the account so that its commits
show as verified.

## Getting started

Requires bash 3.2 or later and the GitHub CLI `gh` (tested with 2.89), logged in
to the account:

```bash
gh auth login
```

Check every repository of the account:

```bash
git clone git@github.com:tiavelum/github-setup.git ~/vc/github-setup
~/vc/github-setup/repo-settings.sh
```

A repository whose settings match prints `ok`; one that differs prints
`diff` and each field that differs, and the run exits 1:

```
  ok  tiavelum/engineering-standards
diff  tiavelum/mac-bootstrap
        allow_rebase_merge true -> false
        delete_branch_on_merge false -> true
==> 1 repository/ies differ; run with --apply to set them
```

## Set the values

Run this after creating a repository, and after changing
`repo-settings.json`:

```bash
~/vc/github-setup/repo-settings.sh --apply
```

It changes the settings of every repository that differs and prints `set`
for each. Name repositories to limit a run to them:

```bash
~/vc/github-setup/repo-settings.sh --apply tiavelum/github-setup
```

Archived repositories and forks are skipped.

## Register the signing key

git signs every commit with the SSH key that the git config names in
`user.signingkey` (tiavelum/mac-config sets it). GitHub shows those commits
as verified only once the same key is registered on the account as a
signing key, a registration separate from the one for pushing. Run this once
per Mac, after the git config is in place:

```bash
~/vc/github-setup/register-signing-key.sh
```

It needs the `admin:ssh_signing_key` scope, which a plain `gh auth login`
does not grant. When the scope is missing, the script adds it with
`gh auth refresh` and you confirm in the browser. Run without a terminal,
it prints that command instead and stops. A key that is already registered
is left alone:

```
    signing key already registered on GitHub: /Users/andi/.ssh/id_ed25519.pub
```

## Content and structure

| File | Holds |
|---|---|
| `repo-settings.sh` | The check, and with `--apply` the change |
| `repo-settings.json` | The values every repository gets: squash merging only, with the pull request's title and description as the commit, and merged branches deleted |
| `register-signing-key.sh` | The registration of the Mac's signing key on the account |
| `.editorconfig`, `.shellcheckrc` | Formatting (`shfmt` reads `.editorconfig`) and linting for the scripts |

## License

MIT. See [LICENSE](LICENSE).
