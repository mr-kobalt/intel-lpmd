{
  description = "Intel Low Power Mode Daemon (lpmd) - Linux daemon for optimizing active idle power";
  # Note: This flake is a community addition and not officially supported by Intel.
  # Flake implementation created by Deepseek Reasoner using OpenCode.

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  # Outputs:
  # - packages.default: the intel-lpmd daemon and configuration files
  # - devShells.default: development environment with build dependencies
  # - nixosModules.default: NixOS module configuring intel-lpmd service
  #   Options:
  #     services.intel-lpmd.enable (bool): enable the daemon service
  #     services.intel-lpmd.package (package): override the package
  #     services.intel-lpmd.configFile (path or string): custom XML configuration
  #   Usage example:
  #     services.intel-lpmd.enable = true;
  #     services.intel-lpmd.configFile = ./custom-config.xml;
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.default = import ./default.nix { inherit pkgs; };

      devShells.default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          autoreconfHook
          pkg-config
          gtk-doc
          autoconf-archive
        ];
        buildInputs = with pkgs; [
          glib
          libxml2
          libnl
          systemd
          upower
        ];
      };
    }) // {
      nixosModules.default = import ./module.nix { inherit self; };
    };
}
