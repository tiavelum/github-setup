# github-setup

Settings for a GitHub account that are not tied to one machine. It gives
every repository of the account the same merge and branch settings, and
reports the repositories that differ.

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

## Content and structure

| File | Holds |
|---|---|
| `repo-settings.sh` | The check, and with `--apply` the change |
| `repo-settings.json` | The values every repository gets: squash merging only, with the pull request's title and description as the commit, and merged branches deleted |
| `.editorconfig`, `.shellcheckrc` | Formatting (`shfmt` reads `.editorconfig`) and linting for the script |

## License

MIT. See [LICENSE](LICENSE).
