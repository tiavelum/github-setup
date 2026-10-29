# github-setup

Settings for a GitHub account. It gives every repository of the account the
same merge settings, branch and tag rulesets and secret scanning, and reports
the repositories that differ, and it registers a Mac's git signing key on the
account so that its commits show as verified.

## Getting started

Requires bash 3.2 or later, `jq` (tested with 1.7) and the GitHub CLI `gh`
(tested with 2.89), logged in to the account:

```bash
gh auth login
```

Check every repository of the account:

```bash
git clone git@github.com:tiavelum/github-setup.git ~/vc/github-setup
~/vc/github-setup/repo-settings.sh
```

A repository whose settings match prints `ok`; one that differs prints
`diff` and each field that differs, and the run exits 1. An archived
repository or a fork prints `skipped` and the reason:

```
ok      tiavelum/engineering-standards
diff    tiavelum/mac-bootstrap
          allow_rebase_merge true -> false
          delete_branch_on_merge false -> true
          ruleset default-branch: missing
          ruleset tags: missing
skipped tiavelum/cli (fork)
==> 1 repository/ies differ; run with --apply to set them
```

| Line | Means |
|---|---|
| `ok` | The repository has every value of `repo-settings.json`. |
| `diff` | The repository differs; each indented line below names one difference. |
| `set` | With `--apply`: the differences listed below it were set. |
| `skipped` | An archived repository or a fork, not checked. |
| `<field> <now> -> <wanted>` | The repository has `<now>`; the file asks for `<wanted>`. |
| `ruleset <name>: missing` | The repository lacks the ruleset; any other line on a ruleset names the rule or parameter that differs. |
| `!! <repository>: could not read its settings` | `gh` could not read the repository, for example without access; the run exits 1. |
| `==>` | The summary of the run. |

## Set the values

Run this after creating a repository, again after its first commit, and
after changing `repo-settings.json`:

```bash
~/vc/github-setup/repo-settings.sh --apply
```

It changes the settings of every repository that differs and prints `set`
for each. Name repositories to limit a run to them:

```bash
~/vc/github-setup/repo-settings.sh --apply tiavelum/github-setup
```

Archived repositories and forks are skipped, whether the run lists the
account's repositories or names them: each prints `skipped`, counts neither
as matching nor as differing, and `--apply` changes nothing on it. A run
in which every repository is skipped ends with `==> no repository
checked; 1 skipped`, giving the number skipped, and exits 0. A
repository without commits gets the rulesets with the run after its first
commit, since its default branch does not exist before.

## What the values set

| Key in `repo-settings.json` | Sets |
|---|---|
| `repository` | Squash merging only, with the pull request's title and description as the commit, and merged branches deleted |
| `security_and_analysis` | Secret scanning and push protection, on public repositories only: a repository of a personal account can enable them nowhere else |
| `rulesets`, `default-branch` | The default branch changes only through a pull request, which needs no approval, and refuses force pushes |
| `rulesets`, `tags` | A pushed tag can be neither moved nor deleted |

The rulesets are checked and set on public repositories only (see Known
limits). They have no bypass, so they hold for the account's owner too. A
parameter of a rule that `repo-settings.json` leaves out is left to GitHub
and not compared; a rule that the repository's ruleset has beyond those
listed shows as a difference, and `--apply` replaces the ruleset with the
one listed.

## Known limits

- Rulesets reach public repositories only. GitHub offers them on a private
  repository only on a paid plan, and the script does not set them there
  even on one, so a private repository gets the merge settings alone.
- The rulesets require no status checks: a ruleset names each check it
  requires, and the checks differ between repositories.
- With force pushes refused, the default branch cannot be renamed, and with
  tags protected, a tag cannot be deleted. To do either, first set the
  ruleset's enforcement to disabled in the repository's settings; the check
  reports the ruleset until `--apply` restores it.

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
| `repo-settings.json` | The values every repository gets: merge settings, secret scanning and the rulesets, as "What the values set" describes them |
| `register-signing-key.sh` | The registration of the Mac's signing key on the account |
| `.editorconfig`, `.shellcheckrc` | Formatting (`shfmt` reads `.editorconfig`) and linting for the scripts |

## License

MIT. See [LICENSE](LICENSE).
