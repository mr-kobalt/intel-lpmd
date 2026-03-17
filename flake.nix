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
      packages.default = pkgs.stdenv.mkDerivation rec {
        pname = "intel-lpmd";
        version = "0.1.0";
        src = ./.;

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

        configureFlags = [
          "--with-systemdsystemunitdir=${placeholder "out"}/lib/systemd/system"
          "--with-dbus-sys-dir=${placeholder "out"}/share/dbus-1/system.d"
        ];

        prePatch = ''
          # Remove gzip and mandb lines from install-data-hook
          sed -i '/^install-data-hook:/,/^[^[:space:]]/ { /gzip.*intel_lpmd\.8/d; /mandb/d; }' Makefile.am
        '';

        postInstall = "";

        meta = with pkgs.lib; {
          description = "Intel Low Power Mode Daemon";
          homepage = "https://github.com/intel/intel-lpmd";
          license = licenses.gpl2Only;
          platforms = platforms.linux;
          maintainers = [];
        };
      };

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
      nixosModules.default = { config, lib, pkgs, ... }: let
        cfg = config.services.intel-lpmd;
      in {
        options.services.intel-lpmd = {
          enable = lib.mkEnableOption "Intel Low Power Mode Daemon";
          package = lib.mkOption {
            type = lib.types.package;
            default = null;
            description = "The intel-lpmd package to use";
            example = lib.literalExpression "pkgs.intel-lpmd";
          };
          configFile = lib.mkOption {
            type = with lib.types; nullOr (oneOf [ path str ]);
            default = null;
            description = ''
              Custom XML configuration file (see man intel_lpmd_config.xml).
              Can be a path to a file or a string containing the XML content.
              If null, the default configuration from the package will be used.
            '';
          };
        };

        config = lib.mkIf (cfg.enable && config.boot.kernelPackages ? kernel) (let
          # Determine which package to use
          package = if cfg.package != null then cfg.package else self.packages.${pkgs.stdenv.hostPlatform.system}.default;
          configDir = "/etc/intel_lpmd";
          configFile = if cfg.configFile != null then
            pkgs.writeText "intel-lpmd-config.xml" (if lib.isString cfg.configFile then cfg.configFile else builtins.readFile cfg.configFile)
          else null;
        in {
          system.activationScripts.intel-lpmd-config = lib.stringAfter [ "etc" ] ''
            mkdir -p ${configDir}
            # Symlink all config files from package
            for f in ${package}/etc/intel_lpmd/*.xml; do
              bn=$(basename "$f")
              if [ ! -e ${configDir}/"$bn" ]; then
                ln -sf "$f" ${configDir}/"$bn"
              fi
            done
            # Override default config if custom config provided
            ${lib.optionalString (configFile != null) ''
              ln -sf ${configFile} ${configDir}/intel_lpmd_config.xml
            ''}
          '';

          systemd.services.intel_lpmd = {
            description = "Intel Linux Energy Optimizer (lpmd) Service";
            documentation = [ "man:intel_lpmd(8)" ];
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];
            path = [ package ];
            serviceConfig = {
              Type = "dbus";
              BusName = "org.freedesktop.intel_lpmd";
              ExecStart = "${package}/bin/intel_lpmd --systemd --dbus-enable";
              Restart = "on-failure";
              RestartSec = 30;
              PrivateTmp = true;
              StateDirectory = "intel_lpmd";
              RuntimeDirectory = "intel_lpmd";
            };
            environment = {
              TDCONFDIR = configDir;
            };
          };
        });
      };
    };
}