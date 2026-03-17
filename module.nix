{ self }:

{ config, lib, pkgs, ... }: let
  cfg = config.services.intel-lpmd;
in {
  options.services.intel-lpmd = {
    enable = lib.mkEnableOption "Intel Low Power Mode Daemon";
    package = lib.mkOption {
      type = with lib.types; nullOr package;
      default = null;
      description = "The intel-lpmd package to use";
      example = lib.literalExpression "intel-lpmd.packages.${pkgs.stdenv.hostPlatform.system}.default";
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
}