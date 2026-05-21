{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;

    # Global tools — available everywhere, not tied to a project
    globalConfig = {
      tools = {
        # ── Runtimes ────────────────────────────────────────────────────────
        go = "latest";
        node = "24";
        rust = "1.93.1";
        uv = "latest";
        python = "3.13";
        bun = "latest";

        # ── Linting / formatting ────────────────────────────────────────────
        markdownlint-cli2 = "0.18.1";
        yamlfmt = "latest";
        yamllint = "latest";
        prettier = "3.7.4";
        shfmt = "latest";
        shellcheck = "latest";
        ruff = "latest";
        actionlint = "latest";

        # ── Go tooling ──────────────────────────────────────────────────────
        golines = "latest";
        golangci-lint = "latest";
        goreleaser = "latest";
        "go:golang.org/x/tools/cmd/goimports" = "latest";
        "go:golang.org/x/tools/gopls" = "latest";
        "go:github.com/spf13/cobra-cli" = "latest";
        "go:github.com/vektra/mockery/v2" = "latest";
        "go:golang.org/x/vuln/cmd/govulncheck" = "latest";
        "go:github.com/google/go-licenses" = "latest";
        "go:google.golang.org/grpc/cmd/protoc-gen-go-grpc" = "latest";
        "go:google.golang.org/protobuf/cmd/protoc-gen-go" = "latest";
        protoc = "latest";

        # ── Infra / IaC ─────────────────────────────────────────────────────
        terragrunt = "latest";
        terraform = "latest";
        terraform-docs = "latest";
        tflint = "latest";
        packer = "latest";
        opentofu = "latest";
        "go:github.com/transcend-io/terragrunt-atlantis-config" = "v1.21.1";

        # ── Kubernetes ──────────────────────────────────────────────────────
        kubectl = "latest";
        k3d = "latest";
        kind = "latest";
        kubebuilder = "latest";
        argocd = "latest";
        talosctl = "1.12.1"; # pin to cluster version
        helm = "3.19.0";
        helm-cr = "1.8.1";
        helm-ct = "3.14.0";
        helm-diff = "3.15.0";
        helm-docs = "1.14.2";
        cilium-cli = "latest";
        cilium-hubble = "latest";

        # ── Rust ────────────────────────────────────────────────────────────
        rust-analyzer = "latest";
        "cargo:tree-sitter-cli" = "latest";

        # ── Node ecosystem ──────────────────────────────────────────────────
        yarn = "latest";
        "npm:@apideck/portman" = "latest";
        "npm:newman" = "latest";

        # ── donaldgifford ───────────────────────────────────────────────────
        "github:donaldgifford/forge" = "latest";
        "github:donaldgifford/docz" = "latest";
        "github:donaldgifford/makefmt" = "latest";

        # ── Misc ────────────────────────────────────────────────────────────
        marksman = "latest";
        checkmake = "latest";
        hugo = "0.140.2";
        typst = "latest";
        git-cliff = "latest";
        boilerplate = "latest";
        syft = "latest";
        "github:golang-migrate/migrate" = "latest";
        "github:locastack/lstk" = "latest";
        cosign = "latest";
      };

      settings = {
        # Auto-install tools when entering a directory with a mise.toml
        not_found_auto_install = true;
        # How often to check plugins for updates
        plugin_autoupdate_last_check_duration = "1 week";
        # Directories to always trust (no confirmation prompt)
        trusted_config_paths = [
          "~/code"
          "~/work"
        ];
        # Load .env files automatically
        env_file = ".env";
        # Use uv for Python venvs (faster than pip)
        python = {
          uv_venv_auto = true;
          # uv_venv_auto = "create|source";
        };
      };
    };
  };
}
