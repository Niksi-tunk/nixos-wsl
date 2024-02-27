{vscode-server, ...}: {
  imports = [vscode-server.nixosModules.home];
  programs = {
    direnv = {
      enable = true;
      enableBashIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
    };

    bash.enable = true;
    git.enable = true;
  };

  home.file.".vscode-server/server-env-setup" = {
    executable = true;
    text = ''
      PATH=$PATH:/run/current-system/sw/bin/

      VSCODE_SERVER_DIR="$( cd "$( dirname "''${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
      echo "Got vscode directory : $VSCODE_SERVER_DIR"
    '';
  };

  services.vscode-server.enable = true;

  home.stateVersion = "23.11";
}
