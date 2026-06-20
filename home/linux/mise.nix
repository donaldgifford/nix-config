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
        go = "1.26.4";
        node = "24";
        rust = "1.93.1";
        uv = "0.10.11";
        python = "3.13";
        bun = "1.3.11";

        # ── Linting / formatting ────────────────────────────────────────────
        markdownlint-cli2 = "0.18.1";
        yamlfmt = "0.21.0";
        yamllint = "1.38.0";
        prettier = "3.7.4";
        shfmt = "3.13.0";
        ruff = "0.15.7";
        actionlint = "1.7.12";

        # ── Go tooling ──────────────────────────────────────────────────────
        golines = "0.13.0";
        golangci-lint = "2.12.2";
        goreleaser = "2.14.3";
        "go:golang.org/x/tools/cmd/goimports" = "0.45.0";
        "go:golang.org/x/tools/gopls" = "0.21.1";
        "go:github.com/spf13/cobra-cli" = "1.3.0";
        "go:github.com/vektra/mockery/v2" = "2.53.6";
        "go:golang.org/x/vuln/cmd/govulncheck" = "1.3.0";
        "go:github.com/google/go-licenses" = "1.6.0";
        "go:google.golang.org/grpc/cmd/protoc-gen-go-grpc" = "1.6.1";
        "go:google.golang.org/protobuf/cmd/protoc-gen-go" = "1.36.11";
        protoc = "latest";

        # ── Infra / IaC ─────────────────────────────────────────────────────
        terragrunt = "0.99.4";
        terraform = "1.14.7";
        terraform-docs = "0.24.0";
        tflint = "0.62.0";
        packer = "1.15.0";
        opentofu = "1.11.5";
        "go:github.com/transcend-io/terragrunt-atlantis-config" = "v1.21.1";

        # ── Kubernetes ──────────────────────────────────────────────────────
        kubectl = "1.35.3";
        k3d = "5.8.3";
        kind = "0.31.0";
        kubebuilder = "4.14.0";
        argocd = "3.3.6";
        talosctl = "1.12.1"; # pin to cluster version
        helm = "3.19.0";
        helm-cr = "1.8.1";
        helm-ct = "3.14.0";
        helm-diff = "3.15.0";
        helm-docs = "1.14.2";
        cilium-cli = "0.19.2";
        cilium-hubble = "1.18.6";

        # ── Rust ────────────────────────────────────────────────────────────
        rust-analyzer = "2026-03-16";
        "cargo:tree-sitter-cli" = "0.26.7";

        # ── Node ecosystem ──────────────────────────────────────────────────
        yarn = "4.13.0";
        "npm:@apideck/portman" = "1.34.0";
        "npm:newman" = "6.2.2";

        # ── donaldgifford ───────────────────────────────────────────────────
        "github:donaldgifford/forge" = "0.7.0";
        "github:donaldgifford/docz" = "0.3.0";
        "github:donaldgifford/makefmt" = "0.0.3";
        "github:donaldgifford/mdp" = "0.2.1";

        # ── Misc ────────────────────────────────────────────────────────────
        marksman = "2026-02-08";
        checkmake = "0.3.2";
        hugo = "0.140.2";
        typst = "0.14.2";
        git-cliff = "2.13.1";
        boilerplate = "0.15.0";
        syft = "1.42.3";
        "github:golang-migrate/migrate" = "4.18.1";
        "github:localstack/lstk" = "0.9.0";
        cosign = "3.1.1";
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
          compile = false;
        };
        node = {
          compile = false;
        };
      };
    };
  };
}
