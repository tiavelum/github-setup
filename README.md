# github-setup

Settings for a GitHub account. It gives every repository of the account the
same merge settings, branch and tag rulesets, secret scanning and issue
labels, and reports the repositories that differ, and it registers a Mac's
git signing key on the account so that its commits show as verified.

## Getting started

Requires bash 3.2 or later, `jq` (tested with 1.7) and the GitHub CLI `gh`
(tested with 2.89), logged in to the account:

```bash
gh auth login
```

Check the repositories of the account:

```bash
git clone git@github.com:tiavelum/github-setup.git ~/vc/github-setup
~/vc/github-setup/repo-settings/repo-settings.sh
```

The repositories that `repo-settings.sh` checks are those that a run without
repository names lists from the account `gh` is logged in to, other than
archived repositories and forks.

A repository whose settings match prints `ok`; one that differs prints
`diff` and each field that differs. An archived repository or a fork
prints `skipped` and the reason:

```
ok      tiavelum/engineering-standards
diff    tiavelum/mac-bootstrap
          allow_rebase_merge true -> false
          delete_branch_on_merge false -> true
          ruleset default-branch: missing
          ruleset tags: missing
          label tiavelum-acts: color 000000 -> ff4101
          label answer-acknowledged: missing
skipped tiavelum/cli (fork)
==> 1 repository/ies differ; run with --apply to set them
```

| Line | Means |
|---|---|
| `ok` | The repository has every value of `repo-settings.json` that is compared for it; rulesets and secret scanning are compared on public repositories only (see Known limits). |
| `diff` | The repository differs; each indented line below names one difference. |
| `set` | With `--apply`: the differences listed below it were set. |
| `skipped` | An archived repository or a fork, not checked. |
| `<field> <now> -> <wanted>` | The repository has `<now>`; the file asks for `<wanted>`. |
| `ruleset <name>: missing` | The repository lacks the ruleset. |
| `ruleset <name>: <part> <now> -> <wanted>` | The ruleset differs in `<part>`: `target`, `enforcement`, `refs`, `bypass_actors`, or `<rule>.<parameter>`. |
| `ruleset <name>: rule <rule> missing` | The ruleset lacks a rule the file lists. |
| `ruleset <name>: rule <rule> is not in repo-settings.json` | The ruleset has a rule the file does not list; `--apply` removes it. |
| `label <name>: missing` | The repository lacks the label. |
| `label <name>: <field> <now> -> <wanted>` | The label differs in `name`, `color` or `description`. |
| `==>` | The summary of the run. When every repository checked matches, it reads `==> every repository checked has the settings of repo-settings.json`. |

The exit status of a run, and the lines it prints when it cannot read or
set a repository or cannot start, are in the
[README of `repo-settings/`](repo-settings/README.md).

## Set the values

Run this after creating a repository, again after its first commit, and
after changing `repo-settings.json`:

```bash
~/vc/github-setup/repo-settings/repo-settings.sh --apply
```

It changes the settings of every repository that differs and prints `set`
for each. A label that is missing is created, and one that differs is
updated. Name repositories to limit a run to them:

```bash
~/vc/github-setup/repo-settings/repo-settings.sh --apply tiavelum/github-setup
```

Archived repositories and forks are skipped, whether the run lists the
account's repositories or names them: each prints `skipped`, counts neither
as matching nor as differing, and `--apply` changes nothing on it. A run
in which every repository is skipped ends with `==> no repository
checked; 1 skipped`, giving the number skipped. A named repository that a
run without names does not list, such as one of another owner, is not one
of the repositories that `repo-settings.sh` checks, even where the summary
line of the run that names it calls it `checked`. A repository without
commits gets the rulesets with the run after its first commit, since its
default branch does not exist before.

What a run prints when it cannot set a repository is in the
[README of `repo-settings/`](repo-settings/README.md).

## What the values set

The values stand in `repo-settings/repo-settings.json`; the
[README of `repo-settings/`](repo-settings/README.md) gives the rules to
follow when changing it.

| Key in `repo-settings.json` | Sets |
|---|---|
| `repository` | Squash merging only, with the pull request's title and description as the commit, and merged branches deleted |
| `security_and_analysis` | Secret scanning and push protection, on public repositories only: a repository of a personal account can enable them nowhere else |
| `rulesets`, `default-branch` | The default branch changes only through a pull request, which needs no approval, and refuses force pushes |
| `rulesets`, `tags` | A pushed tag can be neither moved nor deleted |
| `labels` | The issue labels `tiavelum-decides`, `tiavelum-acts` and `answer-acknowledged`, each with its colour and description, on public and private repositories alike |

The rulesets are compared and set on public repositories only (see Known
limits). They have no bypass, so they hold for the account's owner too. A
parameter of a rule that `repo-settings.json` leaves out is left to GitHub
and not compared; a rule that the repository's ruleset has beyond those
listed shows as a difference, and `--apply` replaces the ruleset with the
one listed.

A label is found by its name. GitHub treats two names that differ only in
case as one label, so a label whose name differs from the listed one only
in case counts as that label: it shows as a `name` difference, and
`--apply` renames it to the listed name. A label's colour, a hexadecimal
code, is compared regardless of case. Labels that `repo-settings.json`
does not list are left alone and not reported.

## Known limits

- Rulesets reach public repositories only. GitHub offers them on a private
  repository only on a paid plan, and the script does not set them there
  even on one, so a private repository gets the merge settings and the
  labels alone.
- The rulesets require no status checks: a ruleset names each check it
  requires, and the checks differ between repositories.
- With force pushes refused, the default branch cannot be renamed, and with
  tags protected, a tag cannot be deleted. To do either, first set the
  ruleset's enforcement to disabled in the repository's settings; the check
  reports the ruleset until `--apply` restores it.
- A run without repository names lists at most 1000 repositories of the
  account; a repository beyond them is neither listed nor checked.

## Register the signing key

git signs every commit with the SSH key that the git config names in
`user.signingkey` (tiavelum/mac-config sets it). GitHub shows those commits
as verified only once the same key is registered on the account as a
signing key, a registration separate from the one for pushing. Run this once
per Mac, after the git config is in place:

```bash
~/vc/github-setup/signing-key/register-signing-key.sh
```

It needs the `admin:ssh_signing_key` scope, which a plain `gh auth login`
does not grant. When the scope is missing, the script adds it and you
confirm in the browser. The key is registered under the Mac's computer
name followed by `signing`:

```
    signing key registered on GitHub as "<computer name> signing"
```

A key that is already registered is left alone:

```
    signing key already registered on GitHub: /Users/andi/.ssh/id_ed25519.pub
```

The lines the script prints when it stops without registering the key are
in the [README of `signing-key/`](signing-key/README.md).

## Content and structure

| Path | Holds |
|---|---|
| `repo-settings/` | The settings of the account's repositories: `repo-settings.sh`, the check, and with `--apply` the change; `repo-settings.json`, the values every repository gets, as "What the values set" describes them; and a [README](repo-settings/README.md) with the exit status of a run, the output of a run that fails and the rules the two files follow |
| `signing-key/` | The account's signing key: `register-signing-key.sh`, the registration of the Mac's signing key on the account, and a [README](signing-key/README.md) with the output of a run that stops and how the key is found and compared |
| `.editorconfig`, `.shellcheckrc` | Formatting (`shfmt` reads `.editorconfig`) and linting for the scripts |

## License

MIT. See [LICENSE](LICENSE).
