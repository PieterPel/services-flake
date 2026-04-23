{ inputs, ... }:

{
  perSystem = { self', inputs', pkgs, system, lib, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;

      # Required for elastic search
      config.allowUnfree = true;

      overlays = [
        (self: super: lib.optionalAttrs super.stdenv.isDarwin {

          # Disable tests, because they are failing on darwin:
          # https://github.com/NixOS/nixpkgs/issues/281214
          pgadmin4 = super.pgadmin4.overrideAttrs (_: {
            doInstallCheck =
              false;
          });

        })

        # FalkorDB is not in nixpkgs; sourced from github:PieterPel/falkordb-flake.
        # Not available on x86_64-darwin (no upstream binary).
        (self: super: lib.optionalAttrs
          (inputs'.falkordb ? packages && inputs'.falkordb.packages ? default)
          { falkordb = inputs'.falkordb.packages.default; }
        )
      ];
    };
  };
}
