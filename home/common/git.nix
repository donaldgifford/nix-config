{
  config,
  pkgs,
  lib,
  ...
}:

let
  # 1Password SSH signing binary path differs between platforms
  op-ssh-sign =
    if pkgs.stdenv.isDarwin then
      "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
    else
      "${pkgs._1password-gui}/bin/op-ssh-sign";
in

{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Donald Gifford";
        email = "dgifford@pm.me";
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOeDUZ8unhW85b8Cu1zmEDp5CNeg0oYpvRpK1eMYQvd donald";
      };

      alias = {
        s = "status -sb";
        lg = "log --oneline --graph --decorate";
        co = "checkout";
        br = "branch";
        undo = "reset HEAD~1 --mixed";
        amend = "commit --amend --no-edit";
        wip = "commit -am 'wip'";
      };

      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rerere.enabled = true;
      fetch.prune = true;
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";

      core = {
        editor = "nvim";
        pager = "delta";
      };

      interactive.diffFilter = "delta --color-only";

      delta = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        light = false;
      };

      gpg.format = "ssh";
      "gpg \"ssh\"".program = op-ssh-sign;
      commit.gpgsign = true;
      tag.gpgsign = true;
    };
  };

  home.activation.installGhExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v gh &> /dev/null; then
      gh extension list | grep -q "dlvhdr/gh-enhance" || gh extension install dlvhdr/gh-enhance 2>/dev/null || echo "⚠ Failed to install gh-enhance (not logged in?)"
    fi
  '';

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
      prompt = "enabled";
      aliases = {
        clean-branches = "poi";
        co = "pr checkout";
        vpr = "pr view --web";
        vr = "repo view --web";
      };
    };
    extensions = with pkgs; [
      gh-dash
    ];
  };
}
