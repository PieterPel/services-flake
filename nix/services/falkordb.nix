{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;

  version = "4.18.1";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/FalkorDB/FalkorDB/releases/download/v${version}/falkordb-macos-arm64v8.so";
      hash = "sha256-7u4zI54Y/6is+hyEbH+g7kzKMX5TZoBSJug0/5fVffg=";
    };
    "x86_64-linux" = {
      url = "https://github.com/FalkorDB/FalkorDB/releases/download/v${version}/falkordb-x64.so";
      hash = "sha256-r7uPohrKRSg4lc/ag9gd6V9K4aMoNGwU41WTaPtkYfE=";
    };
    "aarch64-linux" = {
      url = "https://github.com/FalkorDB/FalkorDB/releases/download/v${version}/falkordb-arm64v8.so";
      hash = "sha256-GnDwMqosyG80FgD79JvrP9l3K5jGhqEnYHSzUdSXlk4=";
    };
  };

  defaultPackage = pkgs.stdenv.mkDerivation {
    pname = "falkordb";
    inherit version;

    src = pkgs.fetchurl (
      sources.${pkgs.stdenv.hostPlatform.system} or (throw ''
        falkordb: unsupported platform ${pkgs.stdenv.hostPlatform.system}
        Supported: ${lib.concatStringsSep ", " (lib.attrNames sources)}
      '')
    );

    dontUnpack = true;

    nativeBuildInputs = lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ];

    buildInputs =
      lib.optionals pkgs.stdenv.isLinux [ pkgs.stdenv.cc.cc.lib ]
      ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.openssl ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib
      cp $src $out/lib/falkordb.so
      chmod 755 $out/lib/falkordb.so
      runHook postInstall
    '';

    # Repoint Homebrew openssl paths to the Nix store so dlopen works without Homebrew.
    postFixup = lib.optionalString pkgs.stdenv.isDarwin ''
      install_name_tool \
        -change /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib \
                ${lib.getLib pkgs.openssl}/lib/libssl.3.dylib \
        -change /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib \
                ${lib.getLib pkgs.openssl}/lib/libcrypto.3.dylib \
        $out/lib/falkordb.so
    '';

    meta = {
      description = "FalkorDB graph database Redis module";
      homepage = "https://www.falkordb.com";
      license = lib.licenses.sspl;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = lib.attrNames sources;
    };
  };
in
{
  options = {
    package = lib.mkOption {
      type = types.package;
      default = defaultPackage;
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
