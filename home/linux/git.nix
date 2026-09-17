{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.git = {
    enable = true;

    settings = {
      user.name = "Donald Gifford";
      user.email = "dgifford@pm.me";

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
      gpg.ssh.program = "${pkgs._1password-gui}/bin/op-ssh-sign";
      commit.gpgsign = true;
      user.signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOeDUZ8unhW85b8Cu1zmEDp5CNeg0oYpvRpK1eMYQvd donald";
    };
  };
}
