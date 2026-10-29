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
          label tiavelum-acts: color 000000 -> c2b416
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
| `labels: could not be read` | `gh` could not read the labels of the repository, so it counts as differing and the run exits 1. |
| `rulesets: could not be read` | `gh` could not read the rulesets of the repository, so it counts as differing and the run exits 1; the `gh` error is the line above it. With `--apply` the run prints the `!!` line below instead of `set`. |
| `!! <repository>: could not read its settings` | `gh` could not read the repository, for example without access; the run exits 1. |
| `!! <repository>: setting the values failed` | With `--apply`: a value could not be set, or the repository still differs afterwards; the run exits 1. |
| `==>` | The summary of the run. |

## Set the values

Run this after creating a repository, again after its first commit, and
after changing `repo-settings.json`:

```bash
~/vc/github-setup/repo-settings.sh --apply
```

It changes the settings of every repository that differs and prints `set`
for each. A label that is missing is created, and one that differs is
updated. Name repositories to limit a run to them:

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
| `labels` | The issue labels `tiavelum-decides`, `tiavelum-acts` and `answer-acknowledged`, each with its colour and description, on public and private repositories alike |

The rulesets are checked and set on public repositories only (see Known
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
| `repo-settings.json` | The values every repository gets: merge settings, secret scanning, the rulesets and the labels, as "What the values set" describes them |
| `register-signing-key.sh` | The registration of the Mac's signing key on the account |
| `.editorconfig`, `.shellcheckrc` | Formatting (`shfmt` reads `.editorconfig`) and linting for the scripts |

## License

MIT. See [LICENSE](LICENSE).
