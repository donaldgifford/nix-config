{ inputs, ... }:

{
  imports = [ inputs.hunk.homeManagerModules.default ];

  programs.hunk = {
    enable = true;
    # When true, sets core.pager = "hunk pager" in programs.git.
    # Conflicting delta entries in git.nix must be commented out (see git.nix).
    enableGitIntegration = true;
    settings = {
      theme = "tokyo-night";
      mode = "split";
      menu_bar = true;
      agent_notes = false;
      line_numbers = true;
    };
  };
}
