# signing-key

This directory holds `register-signing-key.sh`; this README is for whoever
runs the script or changes it, and gives what the
[root README](../README.md#register-the-signing-key) leaves out: how the
script finds and compares the key, and what it prints when it stops.

## How the key is found and compared

- The script reads the path of the key from `user.signingkey` in the git
  config, with `git config --type=path`, and holds no path of its own.
- It compares the first two fields of the key file, the key's type and
  body, with each key registered on the account as a signing key; the
  comment that follows them in the file is not compared.
- It looks for the scope `admin:ssh_signing_key` in the output of
  `gh auth status -h github.com`. Where the scope is missing and standard
  input is a terminal, it prints
  `    gh lacks the admin:ssh_signing_key scope; adding it (confirm in the browser)`
  and runs `gh auth refresh -h github.com -s admin:ssh_signing_key`.
- It registers the key with `gh ssh-key add --type signing`, under the
  title the [root README](../README.md#register-the-signing-key) gives; the
  computer name in it is the output of `scutil --get ComputerName`, or of
  `hostname` where that fails. It then reads the account's signing keys
  again and prints that the key is registered only when it finds the key
  among them.

## When it stops

Each of these lines goes to standard error, and the script exits 1 without
registering the key:

| Line | Means |
|---|---|
| `!! no user.signingkey in the git config — run ~/vc/mac-config/install.sh first` | The git config names no signing key |
| `!! <key file> missing — run gh auth login and let it generate an SSH key` | The file that `user.signingkey` names does not exist |
| `!! gh is not authenticated — run: gh auth login -s admin:ssh_signing_key` | `gh auth status -h github.com` fails |
| `!! gh lacks the admin:ssh_signing_key scope — run: gh auth refresh -h github.com -s admin:ssh_signing_key` | The scope is missing and standard input is not a terminal, so the script does not start the confirmation in the browser. Standard input is not a terminal where the caller redirects it, such as from a file, a pipe or `/dev/null`, or starts the script where there is no terminal at all; a script started from a terminal passes the terminal on to this one unless it redirects input |
| `!! gh ssh-key add reported no error, but the key is not in the account's signing keys` | `gh ssh-key add` succeeded, but reading the account's signing keys afterwards fails or does not show the key |

When `gh` cannot read the account's signing keys, the script prints the
`gh` error in this block and exits 1:

```
!! gh cannot read the account's signing keys:
   <the gh error>
   If this names a missing scope, run this, confirm in the browser, then
   run this script again:

     gh auth refresh -h github.com -s admin:ssh_signing_key
```

When `gh auth refresh` or `gh ssh-key add` fails, the script stops with
the error and the exit status of `gh`.
