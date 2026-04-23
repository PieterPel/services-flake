{ pkgs, lib, name, config, inputs', ... }:
let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkOption {
      type = types.package;
      default = inputs'.falkordb.packages.default;
      description = "The FalkorDB Redis module package.";
    };

    redisPackage = lib.mkPackageOption pkgs "redis" { };

    bind = lib.mkOption {
      type = types.nullOr types.str;
      default = "127.0.0.1";
      description = ''
        The IP interface to bind to.
        `null` means "all interfaces".
      '';
    };

    port = lib.mkOption {
      type = types.port;
      default = 6379;
      description = "The TCP port to accept connections on.";
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Additional text appended to the Redis configuration file.";
    };
  };

  config = {
    outputs.settings.processes."${name}" =
      let
        redisConf = pkgs.writeText "falkordb-redis.conf" ''
          port ${toString config.port}
          ${lib.optionalString (config.bind != null) "bind ${config.bind}"}
          loadmodule ${config.package}/lib/falkordb.so
          ${config.extraConfig}
        '';

        startScript = pkgs.writeShellApplication {
          name = "start-falkordb";
          runtimeInputs = [ pkgs.coreutils config.redisPackage ];
          text = ''
            mkdir -p ${lib.escapeShellArg config.dataDir}
            exec redis-server ${redisConf} --dir ${lib.escapeShellArg config.dataDir}
          '';
        };
      in
      {
        command = startScript;

        readiness_probe = {
          exec.command = "${config.redisPackage}/bin/redis-cli -p ${toString config.port} ping";
          initial_delay_seconds = 2;
          period_seconds = 10;
          timeout_seconds = 4;
          success_threshold = 1;
          failure_threshold = 5;
        };

        availability = {
          restart = "on_failure";
          max_restarts = 5;
        };
      };
  };
}
