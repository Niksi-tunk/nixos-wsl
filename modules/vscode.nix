{
  pkgs,
  config,
  ...
}: let
  niksiUser = config.users.users.${config.wsl.defaultUser};
  User = niksiUser.name;
  Group = niksiUser.group;

  vscode-dir = "${niksiUser.home}/.vscode-server";

  server-env-setup = pkgs.writeShellScript "server-env-setup" ''
    # This shell script is run before checking for vscode version updates.
    # If a newer version is downloaded, this script won't patch that version,
    # resulting in error. Therefore retry is required to patch it.

    echo "== '~/.vscode-server/server-env-setup' SCRIPT START =="

    # Make sure that basic commands are available
    PATH=$PATH:/run/current-system/sw/bin/

    # This shell script uses nixpkgs branch from OS version.
    # If you want to change this behavior, change environment variable below.
    #   e.g. NIXOS_VERSION=unstable
    NIXOS_VERSION=$(nixos-version | cut -d "." -f1,2)
    echo "NIXOS_VERSION detected as \"$NIXOS_VERSION\""

    NIXPKGS_BRANCH=nixos-$NIXOS_VERSION
    PKGS_EXPRESSION=nixpkgs/$NIXPKGS_BRANCH#pkgs

    # Get directory where this shell script is located
    VSCODE_SERVER_DIR="$( cd "$( dirname "''${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    echo "Got vscode directory : $VSCODE_SERVER_DIR"
    echo "If the directory is incorrect, you can hardcode it on the script."

    echo "Patching nodejs binaries..."
    nix shell "$PKGS_EXPRESSION".patchelf "$PKGS_EXPRESSION".stdenv.cc -c bash -c "
        for versiondir in $VSCODE_SERVER_DIR/bin/*/; do
            # Currently only "libstdc++.so.6" needs to be patched
            patchelf --set-interpreter \"\$(cat \$(nix eval --raw $PKGS_EXPRESSION.stdenv.cc)/nix-support/dynamic-linker)\" --set-rpath \"\$(nix eval --raw $PKGS_EXPRESSION.stdenv.cc.cc.lib)/lib/\" \"\$versiondir\"\"node_modules/node-pty/build/Release/spawn-helper\"
            patchelf --set-interpreter \"\$(cat \$(nix eval --raw $PKGS_EXPRESSION.stdenv.cc)/nix-support/dynamic-linker)\" --set-rpath \"\$(nix eval --raw $PKGS_EXPRESSION.stdenv.cc.cc.lib)/lib/\" \"\$versiondir\"\"node\"
        done
    "

    echo "== '~/.vscode-server/server-env-setup' SCRIPT END =="
  '';
in {
  nix.settings.experimental-features = ["nix-command" "flakes"];

  environment.systemPackages = [pkgs.wget];
  systemd.services.foo = {
    script = ''
      mkdir -p ${vscode-dir}
      cp ${server-env-setup} ${vscode-dir}/server-env-setup
    '';

    serviceConfig = {inherit User Group;};

    wantedBy = ["multi-user.target"];
  };
}
