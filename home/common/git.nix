{
  config,
  pkgs,
  lib,
  ...
}:

let
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

      extraConfig = {
        "url \"ssh://git@github.com/donaldgifford\"" = {
          insteadOf = "https://github.com/donaldgifford";
        };
      };

      interactive.diffFilter = "delta --color-only";

      delta = {
        syntax-theme = "tokyonight_night";
        dark = true;
        tabs = 2;

        file-style = "omit";
        file-decoration-style = "none";

        line-numbers = true;
        line-numbers-left-format = "{nm:>4} ";
        line-numbers-right-format = "│ {np:>4} ";
        line-numbers-left-style = "white dim";
        line-numbers-right-style = "#1f2335 dim";
        line-numbers-plus-style = "white dim";
        line-numbers-minus-style = "white dim";
        line-numbers-zero-style = "white dim";

        wrap-left-symbol = " ";
        wrap-right-symbol = " ";
        wrap-right-prefix-symbol = " ";

        plus-style = "syntax \"#152339\"";
        plus-emph-style = "syntax \"#234E88\"";
        minus-style = "syntax \"#2D1F1B\"";
        minus-emph-style = "syntax \"#724022\"";

        hunk-label = "  󰡏 ";
        hunk-header-line-number-style = "#10233A";
        hunk-header-style = "#868E99";
        hunk-header-file-style = "#868E99 dim";
        hunk-header-decoration-style = "#163050 ol ul";
      };

      pager = {
        log = "delta";
        reflog = "delta";
        # show = "delta";
        show = "diffnav";
        difftool = true;
        branch = "";
        diff = "diffnav";
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
