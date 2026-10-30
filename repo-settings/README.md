# repo-settings

This directory holds `repo-settings.sh` and the values in
`repo-settings.json`; this README is for whoever runs the script or changes
either file, and gives what the [root README](../README.md) leaves out: the
exit status of a run, the output of a run that fails, and the rules the
two files follow.

## Exit status

| Status | When |
|---|---|
| 0 | Every repository checked has the values, or the run checked none; also after `--help` |
| 1 | A repository differs, could not be set, or could not be read |
| 2 | The run could not start: see "When a run cannot start" |

## When a repository cannot be read or set

A repository whose settings `gh` cannot read is still one of the
[repositories that `repo-settings.sh` checks](../README.md#getting-started):
the run prints no `ok` for it, so it fails
[TL-29 of tiavelum/engineering-standards](https://github.com/tiavelum/engineering-standards/blob/main/standards/tooling.md#repository-settings).

| Line | Means |
|---|---|
| `labels: could not be read` | `gh` could not read the labels of the repository, so a run without `--apply` prints `diff` for the repository and exits 1; the `gh` error is the line above this one. With `--apply` the run prints `!! <repository>: setting the values failed` instead of `set`. |
| `rulesets: could not be read` | `gh` could not read the rulesets of the repository, so a run without `--apply` prints `diff` for the repository and exits 1; the `gh` error is the line above this one. With `--apply` the run prints `!! <repository>: setting the values failed` instead of `set`. |
| `!! <repository>: could not read its settings -- <error>` | `gh` could not read the repository, for example without access; `<error>` is the last line of the `gh` error, and the run exits 1. |
| `!! <repository>: setting the values failed -- <error>` | With `--apply`: a value could not be set, or the repository still differs afterwards; `<error>` is the last line of the error, where there is one, and the run exits 1. |
| `==> <number> repository/ies could not be checked` | The summary line for the repositories that `gh` could not read, though each of them is one of the repositories checked. |
| `==> <number> repository/ies could not be set` | With `--apply`: the summary line for the repositories that printed `setting the values failed`. |

The `!!` lines go to standard error, the other lines to standard output.

## When the account's repositories cannot be listed

A run without repository names lists the repositories with `gh repo list`.
When that fails, the run prints the `gh` error, checks no repository, and
ends with exit status 0:

```
==> no repository checked; 0 skipped
```

Name the repositories to check them while `gh repo list` fails:

```bash
~/vc/github-setup/repo-settings/repo-settings.sh tiavelum/github-setup
```

## When a run cannot start

The run checks what it needs before it reads any repository. Where
something is missing, it prints one of these lines on standard error, checks
no repository and exits 2:

| Line | Means |
|---|---|
| `unknown option: <option>` | An argument starting with `-` other than `--apply`, `-h` and `--help` |
| `!! <tool> not found -- install it` | `gh` or `jq` is not on the `PATH` |
| `!! gh is not logged in -- run gh auth login` | `gh auth status` fails |
| `!! <path>/repo-settings.json missing` | `repo-settings.json` is not in the directory of the script |
| `!! <path>/repo-settings.json needs repository, security_and_analysis, rulesets and labels` | The file is not valid JSON, or one of the four keys is missing, `null` or `false`; a `jq` error above it names a syntax error |
| `!! could not read the account` | A run without repository names could not read the account `gh` is logged in to; the `gh` error is the line above |

## Changing the script or the values

- `--help` prints lines 2 to 13 of `repo-settings.sh`, so its header
  comment stays within those lines.
- `repo-settings.json` stays in the directory of `repo-settings.sh`, which
  reads it from there wherever the run starts.
- Each key of `repository` is compared with the field of the same name in
  the repository as `gh api repos/<owner>/<name>` returns it, and `--apply`
  sends the whole object when one differs. A key that GitHub does not
  return under that name shows as a difference on every run.
- Each key of `security_and_analysis` is compared by its `status`.
- A ruleset is matched to one of the repository by its `name` and `target`;
  `--apply` sends the whole entry to create it or to replace the matched
  one.
- `--apply` sends a missing label whole, and sends an existing one its
  `color` and `description`, with its listed name as `new_name` where the
  names differ in case.
