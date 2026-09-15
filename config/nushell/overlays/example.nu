# Overlay template — copy to <env>.nu (gitignored) and fill in real values.
#
#   overlay use ~/.config/nushell/overlays/prod.nu   # activate
#   overlay list                                     # see what's loaded
#   overlay hide prod                                # deactivate, env restored
#
# `aws-overlays` (modules/aws.nu) lists whatever *.nu files live here.

export-env {
  $env.AWS_PROFILE = "example"
  $env.AWS_REGION = "us-east-1"
  # $env.KUBECONFIG = ($nu.home-dir | path join ".kube" "example.yaml")
}

# Commands defined here are only in scope while the overlay is active.
export def whereami [] {
  { overlay: "example", profile: $env.AWS_PROFILE, region: $env.AWS_REGION }
}
