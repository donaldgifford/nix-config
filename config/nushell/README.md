# nushell

Secondary shell for k8s / cloud work and anything that benefits from
structured data. zsh stays the login shell; run `nu` to drop in.

## Layout

| path        | owner | notes                                                        |
| ----------- | ----- | ------------------------------------------------------------ |
| `config.nu` | HM    | `programs.nushell` in `home/common/shell.nix`                |
| `env.nu`    | HM    | same                                                         |
| `modules/`  | repo  | linked to `~/.config/nushell/modules`, on `NU_LIB_DIRS`      |
| `overlays/` | repo  | linked to `~/.config/nushell/overlays`; `*.nu` gitignored    |

On macOS nushell keeps `config.nu`/`env.nu` under
`~/Library/Application Support/nushell`; on Linux under `~/.config/nushell`.
Either way the `modules/` link is found through `NU_LIB_DIRS`, so `use k8s.nu`
works the same on both.

## Modules

| file     | import        | commands                                                      |
| -------- | ------------- | ------------------------------------------------------------- |
| `k8s.nu` | `use k8s.nu`  | `k8s pods`, `k8s nodes`, `k8s deployments`, `k8s events`, ... |
| `aws.nu` | `use aws.nu *`| `aws-whoami`, `aws-ec2`, `aws-eks-clusters`, `aws-iam-keys`   |
| `tf.nu`  | `use tf.nu *` | `tf-state`, `tf-plan-summary`, `tf-plan-destructive`, ...     |

`aws` and `tf` export prefixed names on purpose: a namespaced `aws` module
would shadow the `aws` binary (`aws ec2 ...` would hit the module instead).

Every command has a doc comment, so `k8s pods --help` / `aws-ec2 --help`
show flags. `k8s` alone lists the subcommands.

## Adding a module

1. Create `modules/<name>.nu` with `export def` commands (private helpers
   are plain `def`). Nothing else to link — the directory is what's linked.
2. Add a `use <name>.nu` (or `use <name>.nu *`) line to the nushell
   `extraConfig` in `home/common/shell.nix`.
3. Parse-check before rebuilding:
   `nu -n -c 'use ~/code/nix-config/config/nushell/modules/<name>.nu'`

Modules are read when `nu` starts, so editing an existing one only needs a
new shell. Adding a `use` line needs `nrs`.

## Overlays

Per-environment settings (profiles, regions, kubeconfigs) go in
`overlays/<env>.nu`, copied from `overlays/example.nu`. Activate with
`overlay use ~/.config/nushell/overlays/<env>.nu`, drop with
`overlay hide <env>`. Only `example.nu` is tracked.
