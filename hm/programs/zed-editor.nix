{ pkgs }:
{
  enable = true;
  package = pkgs.zed-editor;

  extensions = [ "nix" "haskell" ];

  # Merge these settings with local preferences and AI provider settings.
  mutableUserSettings = true;

  userSettings = {
    # Use each project's development environment for HLS, GHC and Ormolu.
    load_direnv = "direct";

    languages = {
      Nix.language_servers = [ "nil" ];
      Haskell = {
        tab_size = 2;
        format_on_save = "on";
        formatter = "language_server";
      };
    };

    lsp = {
      nil.binary.path = "${pkgs.nil}/bin/nil";

      hls = {
        # Match VS Code: use the HLS on the project's PATH.
        binary = {
          path = "haskell-language-server";
          arguments = [ "--lsp" ];
        };
        settings.haskell = {
          formattingProvider = "ormolu";
          plugin.ormolu.config.external = true;
          sessionLoading = "multipleComponents";
        };
      };
    };
  };
}
