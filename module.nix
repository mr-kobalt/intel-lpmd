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
    environment.systemPackages = [ package ];

    system.activationScripts.intel-lpmd-config = lib.stringAfter [ "etc" ] ''
      mkdir -p ${configDir}
      
      # Remove any existing symlinks in the directory
      find ${configDir} -maxdepth 1 -type l -name "*.xml" -delete
      
      ${lib.optionalString (configFile != null) ''
        # User provided custom config: only symlink their config as intel_lpmd_config.xml
        ln -sf ${configFile} ${configDir}/intel_lpmd_config.xml
        echo "Using custom intel-lpmd configuration: ${configFile}"
      ''}
      ${lib.optionalString (configFile == null) ''
        # No custom config: symlink all default configs from package
        for f in ${package}/etc/intel_lpmd/*.xml; do
          bn=$(basename "$f")
          ln -sf "$f" ${configDir}/"$bn"
        done
        echo "Using default intel-lpmd configurations from package"
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
      # TDCONFDIR is compiled into the binary as /etc/intel_lpmd
      # No need to set environment variable
    };
  });
}