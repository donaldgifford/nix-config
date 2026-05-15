{ inputs, ... }:

{
  imports = [ inputs.hunk.homeManagerModules.default ];

  programs.hunk = {
    enable = true;
    # When true, sets core.pager = "hunk pager" in programs.git.
    # Conflicting delta entries in git.nix must be commented out (see git.nix).
    enableGitIntegration = true;
    settings = {
      theme = "graphite";
      mode = "split";
      line_numbers = true;
    };
  };
}
