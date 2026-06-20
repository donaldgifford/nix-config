# Local Working Config vs Repo Config — Diff Report

Comparing `backup/workstation-local/` (local working, boots on reboot) against the repo (`~/code/nix-config`).

---

## configuration.nix

`backup/workstation-local/configuration.nix` vs `hosts/workstation/configuration.nix`

Differences: repo adds a header comment, fixes whitespace (indentation on greetd command, nix-ld block), adds `llvmPackages.libclang.lib` to nix-ld, and normalizes a trailing space.

```diff
--- local working
+++ repo
@@ -1,3 +1,13 @@
+# ── NixOS Workstation Configuration ───────────────────────────────────────────
+#
+# Copy your existing /etc/nixos/configuration.nix content here.
+# Also copy hardware-configuration.nix into this directory.
+#
+# Key things to update when migrating:
+# - Remove the home-manager import if it's in here (it's in flake.nix now)
+# - Keep all system-level config: boot, networking, nvidia, sway, etc.
+# - The flake handles HM wiring, so this file is purely system config
+#
 {
   config,
   pkgs,
@@ -171,7 +181,7 @@
     enable = true;
     settings = {
       default_session = {
-    	command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'sway --unsupported-gpu'";
+        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'sway --unsupported-gpu'";
         user = "greeter";
       };
     };
@@ -240,16 +250,17 @@
   # ── Nix LD ────────────────────────────────────────────────────────────────────
-programs.nix-ld = {
-  enable = true;
-  libraries = with pkgs; [
-    stdenv.cc.cc.lib
-    zlib
-    openssl
-    glib
-    libgcc
-  ];
-};
+  programs.nix-ld = {
+    enable = true;
+    libraries = with pkgs; [
+      stdenv.cc.cc.lib
+      zlib
+      openssl
+      glib
+      libgcc
+      llvmPackages.libclang.lib
+    ];
+  };
```

---

## hardware-configuration.nix

`backup/workstation-local/hardware-configuration.nix` vs `hosts/workstation/hardware-configuration.nix`

**Whitespace/formatting only.** Same UUIDs, same mounts, same content. Repo version is `nixfmt`-formatted.

---

## flake.nix

`backup/workstation-local/flake.nix` vs `flake.nix` (repo root)

This is the biggest structural difference — the local flake is NixOS-only with stable nixpkgs; the repo flake is multi-platform with unstable nixpkgs.

```diff
--- local working
+++ repo
@@ -1,30 +1,78 @@
 {
-  description = "NixOS system configuration";
+  description = "Donald's multi-platform Nix configuration";

   inputs = {
-    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
+    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
+
+    nix-darwin = {
+      url = "github:nix-darwin/nix-darwin";
+      inputs.nixpkgs.follows = "nixpkgs";
+    };
+
     home-manager = {
-      url = "github:nix-community/home-manager/release-25.11";
+      url = "github:nix-community/home-manager";
       inputs.nixpkgs.follows = "nixpkgs";
     };
-    lazyvim-nix = {
-      url = "github:pfassina/lazyvim-nix";
+
+    _1password-shell-plugins.url = "github:1Password/shell-plugins";
+
+    hunk = {
+      url = "github:modem-dev/hunk";
       inputs.nixpkgs.follows = "nixpkgs";
     };
+
+    # lazyvim-nix = {
+    #   url = "github:pfassina/lazyvim-nix";
+    #   inputs.nixpkgs.follows = "nixpkgs";
+    # };
   };

-  outputs = { self, nixpkgs, home-manager, ... } @ inputs: {
-    nixosConfigurations."workstation" = nixpkgs.lib.nixosSystem {
-      system = "x86_64-linux";
-      modules = [
-        ./configuration.nix
-        home-manager.nixosModules.home-manager {
-          home-manager.useGlobalPkgs = true;
-          home-manager.useUserPackages = true;
-          home-manager.extraSpecialArgs = { inherit inputs; };
-          home-manager.users.donald = import ./home.nix;
-        }
-      ];
+  outputs = { self, nixpkgs, nix-darwin, home-manager, ... }@inputs: {
+
+      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
+        system = "x86_64-linux";
+        specialArgs = { inherit inputs; };
+        modules = [
+          ./hosts/workstation/configuration.nix
+          ./hosts/workstation/hardware-configuration.nix
+          home-manager.nixosModules.home-manager
+          {
+            home-manager.useGlobalPkgs = true;
+            home-manager.useUserPackages = true;
+            home-manager.users.donald = import ./home/linux.nix;
+            home-manager.backupFileExtension = "bak";
+            home-manager.extraSpecialArgs = { inherit inputs; };
+          }
+        ];
+      };
+
+      darwinConfigurations."donald-mbp" = nix-darwin.lib.darwinSystem {
+        system = "aarch64-darwin";
+        specialArgs = { inherit inputs; };
+        modules = [
+          ./hosts/macbook/darwin.nix
+          home-manager.darwinModules.home-manager
+          {
+            home-manager.useGlobalPkgs = true;
+            home-manager.useUserPackages = true;
+            home-manager.users.donaldgifford = import ./home/darwin.nix;
+            home-manager.backupFileExtension = "bak";
+            home-manager.extraSpecialArgs = { inherit inputs; };
+          }
+        ];
+      };
     };
-  };
 }
```

---

## home.nix vs home/linux.nix (entry point)

`backup/workstation-local/home.nix` vs `home/linux.nix`

```diff
--- local working (home.nix)
+++ repo (home/linux.nix)
@@ imports
-    inputs.lazyvim-nix.homeManagerModules.default
-    ./home/packages.nix
-    ./home/shell.nix
-    ./home/git.nix
-    ./home/ssh.nix
-    ./home/mise.nix
-    ./home/neovim.nix
-    ./home/sway.nix
-    ./home/waybar.nix
-    ./home/wofi.nix
-    ./home/swaylock.nix
-    ./home/tmux.nix
+    # inputs.lazyvim-nix.homeManagerModules.default
+    ./common/configs.nix
+    ./common/shell.nix
+    ./common/git.nix
+    ./common/ssh.nix
+    ./common/neovim.nix
+    ./common/tmux.nix
+    ./common/mise.nix
+    ./common/packages.nix
+    ./common/fonts.nix
+    ./common/onepassword-plugins.nix
+    ./common/hunk.nix
+    ./linux/sway.nix
+    ./linux/waybar.nix
+    ./linux/wofi.nix
+    ./linux/swaylock.nix

@@ sessionVariables — repo adds:
+    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
+    BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${pkgs.glibc.dev}/include -isystem ...";

@@ pointerCursor — same content, just moved after sessionVariables in repo

@@ repo adds commented-out GPG agent section
```

Key differences:
- Local uses `lazyvim-nix` module (active); repo has it commented out
- Repo adds `configs.nix`, `fonts.nix`, `onepassword-plugins.nix`, `hunk.nix` (not in local)
- Repo adds `LIBCLANG_PATH` and `BINDGEN_EXTRA_CLANG_ARGS` session variables
- Repo uses `./common/` and `./linux/` paths; local uses flat `./home/`

---

## git.nix

`backup/workstation-local/home/git.nix` vs `home/common/git.nix`

Major differences — repo version is much more complete.

```diff
--- local working
+++ repo

 Repo adds:
 + Platform-aware op-ssh-sign path (Darwin vs Linux)
 + user.signingkey in user block
 + merge.conflictstyle = "diff3"
 + diff.colorMoved = "default"
 + URL rewriting: https://github.com/donaldgifford → ssh://
 + Full delta Tokyo Night theme config (syntax-theme, line-numbers styling, hunk labels, etc.)
 + diffnav as show/diff pager
 + tag.gpgsign = true
 + programs.gh (GitHub CLI) with aliases and gh-dash extension
 + home.activation.installGhExtensions hook

 Local has:
 - Simple delta config (navigate, side-by-side, line-numbers, light=false)
 - core.pager = "delta" (repo disables this — hunk owns core.pager)
 - interactive.diffFilter = "delta --color-only" (repo disables — testing hunk)
 - Simpler gpg.ssh.program pointing directly at pkgs._1password-gui
```

---

## ssh.nix

`backup/workstation-local/home/ssh.nix` vs `home/common/ssh.nix`

Local is minimal (8 lines); repo is comprehensive (182 lines).

```diff
--- local working
+++ repo

 Local has ONLY:
   programs.ssh.enable = true;
   enableDefaultConfig = false;
   matchBlocks."*".identityAgent = "~/.1password/agent.sock";

 Repo adds:
 + Platform-aware 1Password agent socket (Darwin vs Linux)
 + IdentitiesOnly = "yes" (prevents too many auth failures)
 + 1Password SSH Bookmarks include
 + 10 Proxmox server entries (proxmox1-5, root + terraform variants)
 + VM entries (k3s, asss, gitea.fartlab.dev)
 + UCG Fiber, 4x DNS servers, Home Assistant
 + Claude Ops hosts (donald3, fc-test, remote-claude, stoat)
 + NixOS workstation, GitHub, Forgejo
```

---

## shell.nix

`backup/workstation-local/home/shell.nix` vs `home/common/shell.nix`

Substantially different — repo version is a major evolution.

```diff
Key differences:

 Zsh plugins:
 - Local: HM built-in syntaxHighlighting + autosuggestion (enabled)
 + Repo: Zinit plugin manager with fast-syntax-highlighting, zsh-autosuggestions,
          zsh-completions, fzf-tab, history-substring-search, zsh-vi-mode

 History:
 - Local: 50000
 + Repo: 100000

 Aliases:
 - Local: simple ls/ll/la with eza
 + Repo: richer eza flags (--group-directories-first, --git, --hyperlink, etc.)
 + Repo adds: fp (fzf+bat preview), sp (sesh connect), kk, gcl
 - Local: NixOS aliases point to /etc/nixos
 + Repo: platform-aware aliases point to ~/code/nix-config

 initContent:
 - Local: simple completion, keybindings, fzf/zoxide/1password sourcing, FZF_DEFAULT_OPTS (Catppuccin)
 + Repo: full Zinit bootstrap, OMZ snippets (git, kubectl, aws, terraform, docker, helm),
          vi mode (jk escape), Tokyo Night colors, krew PATH, yazi wrapper,
          hm-diff utility function

 Starship:
 - Local: full inline starship config in shell.nix (format, symbols, colors, etc.)
 + Repo: just `programs.starship.enable = true` (config likely in config/starship/)

 Fzf:
 - Local: minimal
 + Repo: full Tokyo Night color scheme via defaultOptions

 Repo adds:
 + programs.zoxide (with enableZshIntegration = false, manual init in initContent)
 + programs.direnv with nix-direnv
```

---

## packages.nix

`backup/workstation-local/home/packages.nix` vs `home/common/packages.nix`

Different package sets — repo is more comprehensive and cross-platform.

```diff
 Local-only packages (not in repo):
 - python313, nodejs_24 (mise manages these in repo)
 - htop, zip (in system packages)
 - kubectl, k9s, helm, terraform, fluxcd (mise manages in repo)

 Repo-only packages:
 + neovim, lazygit, httpie, tree, watch
 + GNU tools: coreutils, gnused, gnugrep, gawk, findutils
 + Nix tooling: nixd, nil, nixfmt, statix, deadnix, nix-direnv, nvd
 + gh, forgejo-cli, krew
 + starship, sesh, direnv, mise, btop, yazi
 + xdg-utils (Linux)
 + ghostty-bin, checkmake (macOS)

 Both have:
   eza, bat, ripgrep, fd, fzf, zoxide, delta, jq/yq, curl, wget, unzip
   awscli2
   _1password-cli, _1password-gui (Linux)
   wl-clipboard, grim, slurp, brightnessctl, pamixer, playerctl, pavucontrol (Linux)
```

---

## tmux.nix

`backup/workstation-local/home/tmux.nix` vs `home/common/tmux.nix`

```diff
 Local has:
 - programs.sesh block (active, with plugin settings)

 Repo has:
 + claude-tmux-notify plugin (custom, fetched from GitHub)
 + claude-tmux-notify in status bar
 + home.activation.claudeTmuxNotifyLink (stable symlink for rebuild)
 + programs.sesh block commented out (was active in local)
```

---

## mise.nix

`backup/workstation-local/home/mise.nix` vs `home/common/mise.nix`

Local is minimal; repo is comprehensive.

```diff
 Local tools (all "latest"):
   go, uv, markdownlint-cli2, yamlfmt, yamllint, prettier, golines, golangci-lint

 Repo tools (pinned versions):
 + go, node, rust, uv, python, bun (runtimes)
 + markdownlint-cli2, yamlfmt, yamllint, prettier, shfmt, ruff, actionlint (linting)
 + golines, golangci-lint, goreleaser, goimports, gopls, cobra-cli, mockery, govulncheck, etc. (Go)
 + terragrunt, terraform, terraform-docs, tflint, packer, opentofu (IaC)
 + kubectl, k3d, kind, kubebuilder, argocd, talosctl, helm, cilium-cli, etc. (K8s)
 + rust-analyzer, cargo:tree-sitter-cli (Rust)
 + yarn, npm:@apideck/portman, npm:newman (Node)
 + forge, docz, makefmt, mdp (donaldgifford tools)
 + marksman, checkmake, hugo, typst, git-cliff, boilerplate, syft, etc. (misc)

 Repo settings add:
 + python.compile = false
 + node.compile = false
```

---

## neovim.nix

`backup/workstation-local/home/neovim.nix` vs `home/common/neovim.nix`

Completely different approaches.

```diff
 Local:
   programs.lazyvim enabled with full config:
   - Language extras (cmake, toml, typescript, go, helm, docker, nix, terraform, yaml, json, markdown, typst, bash, python, rust)
   - UI extras (treesitter-context, navic, neo-tree, mini-hipatterns)
   - extraPackages: nixd, alejandra, statix, deadnix, gcc, tree-sitter, lua-language-server, stylua,
     typescript-language-server, prettier, nodejs, biome, dockerfile-language-server, hadolint, helm-ls,
     markdownlint-cli, mdformat, sqls, taplo, vscode-langservers-extracted, cmake-language-server,
     delve, lldb, lazygit, ripgrep, fd
   - mason disabled (replaced by nix)
   - configFiles = ./nvim (points to local nvim/ dir)

 Repo:
   programs.neovim NOT enabled (comment explains: conflicts with mkOutOfStoreSymlink)
   neovim binary provided via packages.nix
   Config managed by symlink in configs.nix
   Full lazyvim config commented out below for reference
```

---

## sway.nix

**Identical.** No differences.

## waybar.nix

**Identical.** No differences.

## wofi.nix

**Identical.** No differences.

## swaylock.nix

**Identical.** No differences.

---

## nvim/ lua files

`backup/workstation-local/home/nvim/` vs `home/common/nvim/`

Most files identical. Differences:

### Only in local (not in repo):
- `lua/plugins/example.lua`

### format.lua
Indentation change (spaces → tabs) plus repo adds a `makefmt` formatter:
```diff
+				makefmt = {
+					command = "makefmt",
+					stdin = true,
+				},
```

### mdp.lua
Indentation change (spaces → tabs) plus theme difference:
```diff
-      theme = "dark",
+      theme = "donald",
```

---

## Files only in repo (no local counterpart)

| File | Purpose |
|------|---------|
| `home/common/configs.nix` | Symlinks `config/` dotfiles into `~/.config` via `mkOutOfStoreSymlink` |
| `home/common/fonts.nix` | Berkeley Mono font installation (conditional on font files existing) |
| `home/common/onepassword-plugins.nix` | 1Password shell plugin integration |
| `home/common/hunk.nix` | Hunk git diff viewer |
| `home/common/claude.nix` | Claude Code specific config |
| `hosts/macbook/darwin.nix` | macOS system config (not relevant to workstation) |
| `home/darwin.nix` | macOS home-manager entry point (not relevant to workstation) |

## Files only in local (no repo counterpart)

| File | Purpose |
|------|---------|
| `home/nvim/lua/plugins/example.lua` | LazyVim example plugin file |

---

## Summary

| File | Status |
|------|--------|
| configuration.nix | Whitespace + repo adds nix-ld libclang, header comment |
| hardware-configuration.nix | Whitespace/formatting only |
| flake.nix | **Major** — stable vs unstable, single vs multi-platform |
| home.nix / linux.nix | **Major** — different imports, lazyvim-nix, extra modules |
| git.nix | **Major** — repo adds signing, delta theme, gh CLI, URL rewriting |
| ssh.nix | **Major** — local is minimal, repo has all host blocks |
| shell.nix | **Major** — repo uses Zinit, vi mode, richer aliases, Tokyo Night |
| packages.nix | **Major** — different package sets, repo is cross-platform |
| tmux.nix | **Moderate** — repo adds claude-tmux-notify, sesh commented out |
| mise.nix | **Major** — local has 8 tools at latest, repo has 60+ pinned |
| neovim.nix | **Major** — local uses lazyvim-nix module, repo uses symlinked config |
| sway.nix | Identical |
| waybar.nix | Identical |
| wofi.nix | Identical |
| swaylock.nix | Identical |
| nvim lua files | Mostly identical — minor format.lua and mdp.lua diffs |
