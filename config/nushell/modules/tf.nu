# tf — structured Terraform / OpenTofu helpers.
#
# Imported flat from config.nu (`use tf.nu *`) with `tf-` prefixed names,
# so the `tf` alias (terraform) and `tofu` keep working. The binary is
# picked from $env.TF_BIN (default: terraform) so `$env.TF_BIN = "tofu"`
# switches every command to OpenTofu.

# ── private helpers ──────────────────────────────────────────────────────────

def tf-bin [] { $env.TF_BIN? | default "terraform" }

# `terraform show -json` on a plan file, or the current state when none given
def show-json [plan?: string] {
  if $plan == null {
    ^(tf-bin) show -json | from json
  } else {
    ^(tf-bin) show -json $plan | from json
  }
}

# Walk root + child modules and collect every resource
def all-resources [module: record] {
  ($module.resources? | default [])
    | append ($module.child_modules? | default [] | each {|m| all-resources $m } | flatten)
}

# ── state ────────────────────────────────────────────────────────────────────

# Resources in the current state: address, type, name, module
export def tf-state [
  --type (-t): string                  # filter by resource type (e.g. aws_instance)
] {
  let root = (show-json | get values?.root_module? | default { resources: [] })
  all-resources $root
    | each {|r|
        {
          address: $r.address
          type: $r.type
          name: $r.name
          module: ($r.address | str replace -r '\.?[^.]+\.[^.]+$' '' | if $in == "" { "root" } else { $in })
          provider: ($r.provider_name | str replace -r '.*/' '')
        }
      }
    | if $type == null { $in } else { where type == $type }
    | sort-by address
}

# Resource counts grouped by type
export def tf-resources [] {
  tf-state
    | group-by type
    | transpose type resources
    | each {|g| { type: $g.type, count: ($g.resources | length) } }
    | sort-by count -r
}

# Outputs of the current state as a record (sensitive values redacted)
export def tf-outputs [] {
  ^(tf-bin) output -json
    | from json
    | transpose name meta
    | each {|o|
        {
          name: $o.name
          value: (if ($o.meta.sensitive? | default false) { "<sensitive>" } else { $o.meta.value })
          sensitive: ($o.meta.sensitive? | default false)
        }
      }
}

# ── plans ────────────────────────────────────────────────────────────────────

# Summarise a saved plan file: one row per changed resource with its actions
export def tf-plan-summary [
  plan: string                         # path to a plan produced by `terraform plan -out`
] {
  show-json $plan
    | get resource_changes? | default []
    | where {|c| ($c.change.actions | any {|a| $a != "no-op" }) }
    | each {|c|
        {
          action: ($c.change.actions | str join "+")
          address: $c.address
          type: $c.type
          reason: ($c.action_reason? | default "")
        }
      }
    | sort-by action address
}

# Counts per action for a plan file (create / update / delete / replace)
export def tf-plan-counts [plan: string] {
  tf-plan-summary $plan
    | group-by action
    | transpose action changes
    | each {|g| { action: $g.action, count: ($g.changes | length) } }
}

# Only the destructive changes in a plan (delete or delete+create replace)
export def tf-plan-destructive [plan: string] {
  tf-plan-summary $plan | where action =~ "delete"
}

# ── workspaces ───────────────────────────────────────────────────────────────

# Workspaces with the current one flagged
export def tf-workspaces [] {
  ^(tf-bin) workspace list
    | lines
    | where ($it | str trim) != ""
    | each {|l| { workspace: ($l | str replace -r '^\*?\s*' ''), current: ($l | str starts-with "*") } }
}

# ── providers ────────────────────────────────────────────────────────────────

# Provider versions pinned in .terraform.lock.hcl for the current dir
export def tf-providers [] {
  if not (".terraform.lock.hcl" | path exists) {
    error make { msg: "no .terraform.lock.hcl here — run init first" }
  }
  open --raw .terraform.lock.hcl
    | parse -r 'provider "(?<provider>[^"]+)"\s*\{\s*version\s*=\s*"(?<version>[^"]+)"'
    | update provider { str replace -r '^registry\.(terraform|opentofu)\.(io|org)/' '' }
}
