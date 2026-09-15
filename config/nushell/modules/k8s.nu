# k8s — structured kubectl helpers.
#
# Loaded namespaced from config.nu (`use k8s.nu`), so commands are
# `k8s pods`, `k8s nodes`, ... Run `k8s` for the list, `k8s pods --help`
# for a command's docs. Everything goes through `kubectl ... -o json`, so
# the current context/kubeconfig apply as usual.

# ── private helpers ──────────────────────────────────────────────────────────

# `-A` or `-n <ns>` as a flag list, for spreading into kubectl
def ns-flags [namespace: string, all: bool] {
  if $all { ["-A"] } else { ["-n" $namespace] }
}

# kubectl get <resource> as a list of items
def get-items [resource: string, flags: list<string>] {
  kubectl get $resource ...$flags -o json | from json | get items
}

def container-statuses [pod: record] {
  $pod.status.containerStatuses? | default []
}

# ── pods ─────────────────────────────────────────────────────────────────────

# List pods as a table: name, namespace, phase, ready/total, restarts, node, age
export def pods [
  --namespace (-n): string = "default"  # namespace (ignored with --all)
  --all (-A)                            # all namespaces
  --not-running                         # only pods whose phase != Running
] {
  get-items pods (ns-flags $namespace $all)
    | each {|p|
        let cs = (container-statuses $p)
        {
          name: $p.metadata.name
          namespace: $p.metadata.namespace
          phase: $p.status.phase
          ready: $"(($cs | where ready == true | length))/($cs | length)"
          restarts: ($cs | each { $in.restartCount } | math sum)
          node: ($p.spec.nodeName? | default "")
          age: ($p.metadata.creationTimestamp | into datetime)
        }
      }
    | if $not_running { where phase != "Running" } else { $in }
}

# Pods sorted by restart count (highest first), above --min restarts
export def restarts [
  --namespace (-n): string = "default"
  --all (-A)
  --min (-m): int = 1                   # minimum restart count to show
] {
  pods -n $namespace --all=$all
    | where restarts >= $min
    | sort-by restarts -r
}

# ── nodes ────────────────────────────────────────────────────────────────────

# Node summary: status, roles, kubelet version, capacity, OS, taints
export def nodes [] {
  get-items nodes []
    | each {|n|
        {
          name: $n.metadata.name
          ready: ($n.status.conditions | where type == "Ready" | get 0.status)
          roles: ($n.metadata.labels | transpose k v | where k =~ "node-role" | get k
                  | each { str replace -r '.*node-role.kubernetes.io/' '' } | str join ",")
          version: $n.status.nodeInfo.kubeletVersion
          cpu: $n.status.capacity.cpu
          memory: $n.status.capacity.memory
          os: $n.status.nodeInfo.osImage
          taints: ($n.spec.taints? | default [] | get key | str join ",")
        }
      }
}

# ── deployments ──────────────────────────────────────────────────────────────

# Deployments with desired/ready/available replica counts
export def deployments [
  --namespace (-n): string = "default"
  --all (-A)
  --unhealthy                           # only where ready != desired
] {
  get-items deployments (ns-flags $namespace $all)
    | each {|d|
        {
          name: $d.metadata.name
          namespace: $d.metadata.namespace
          desired: ($d.spec.replicas? | default 0)
          ready: ($d.status.readyReplicas? | default 0)
          available: ($d.status.availableReplicas? | default 0)
        }
      }
    | if $unhealthy { where ready != desired } else { $in }
}

# Every container image running in the cluster, with a usage count
export def images [
  --namespace (-n): string = "default"
  --all (-A)
] {
  get-items pods (ns-flags $namespace $all)
    | each {|p| $p.spec.containers | get image }
    | flatten
    | uniq -c
    | rename image count
    | sort-by count -r
}

# ── events ───────────────────────────────────────────────────────────────────

# Recent Warning events, newest first
export def events [
  --namespace (-n): string = "default"
  --all (-A)
  --limit (-l): int = 25
  --any-type                            # include Normal events too
] {
  get-items events (ns-flags $namespace $all)
    | if $any_type { $in } else { where type == "Warning" }
    | each {|e|
        {
          namespace: $e.metadata.namespace
          object: $"($e.involvedObject.kind)/($e.involvedObject.name)"
          reason: $e.reason
          message: $e.message
          last: ($e.lastTimestamp? | default $e.eventTime? | default "" | into datetime)
        }
      }
    | sort-by last -r
    | first $limit
}

# Warning events grouped by reason — spot patterns fast
export def event-reasons [
  --namespace (-n): string = "default"
  --all (-A)
] {
  get-items events (ns-flags $namespace $all)
    | where type == "Warning"
    | group-by reason
    | transpose reason events
    | each {|g| { reason: $g.reason, count: ($g.events | length) } }
    | sort-by count -r
}

# ── resource usage ───────────────────────────────────────────────────────────

# `kubectl top pods` as a sortable table (memory in Mi, cpu in m)
export def top [
  --namespace (-n): string = "default"
  --all (-A)
] {
  let flags = (ns-flags $namespace $all)
  let pattern = if $all { '{namespace} {name} {cpu} {memory}' } else { '{name} {cpu} {memory}' }
  kubectl top pods ...$flags --no-headers
    | lines
    | parse $pattern
    | update cpu { str replace 'm' '' | into int }
    | update memory { str replace 'Mi' '' | into int }
    | sort-by memory -r
}

# ── secrets ──────────────────────────────────────────────────────────────────

# Decode every key of a Secret into a key/value table
export def secret [
  name: string
  --namespace (-n): string = "default"
] {
  kubectl get secret $name -n $namespace -o json
    | from json
    | get data
    | transpose key value
    | update value { decode base64 | decode }
}

# ── contexts ─────────────────────────────────────────────────────────────────

# Show the current context, or switch to one
export def ctx [name?: string] {
  if $name == null {
    kubectl config current-context
  } else {
    kubectl config use-context $name
  }
}

# All kubeconfig contexts with their cluster and user
export def contexts [] {
  kubectl config view -o json | from json | get contexts
    | each {|c| { name: $c.name, cluster: $c.context.cluster, user: $c.context.user } }
}

# Run a kubectl command against every context, collecting output per context
export def all-contexts [...args: string] {
  kubectl config get-contexts -o name | lines | each {|ctx|
    let r = (kubectl --context $ctx ...$args | complete)
    { context: $ctx, exit_code: $r.exit_code, output: ($r.stdout | str trim) }
  }
}

# ── port-forward / watch ─────────────────────────────────────────────────────

# Port-forward to a deployment: k8s pf my-app 8080 80
export def pf [
  deployment: string
  local_port: int
  remote_port: int
  --namespace (-n): string = "default"
] {
  print $"localhost:($local_port) → ($deployment):($remote_port) \(($namespace)\)"
  kubectl port-forward -n $namespace $"deployment/($deployment)" $"($local_port):($remote_port)"
}

# Poll `k8s pods` every few seconds (Ctrl-C to stop)
export def watch [
  --namespace (-n): string = "default"
  --all (-A)
  --interval (-i): int = 3
] {
  loop {
    clear
    print $"(date now | format date '%H:%M:%S')  ns=(if $all { 'all' } else { $namespace })"
    pods -n $namespace --all=$all | table
    sleep ($interval * 1sec)
  }
}
