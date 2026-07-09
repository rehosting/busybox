{
  description = "busybox (rehosting fork): guest userland, cross-built for every guest arch";

  nixConfig = {
    extra-substituters = [ "https://rehosting-tools.cachix.org" ];
    extra-trusted-public-keys = [
      "rehosting-tools.cachix.org-1:iNKSaFwG7MfGn6Fk7oTmIcLHqfffQ+cQIE5gWc6MlY0="
    ];
  };

  # Pinned to the same nixpkgs commit as penguin / penguin-tools so the cross
  # toolchains are byte-identical and shared through Cachix.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/b6067cc0127d4db9c26c79e4de0513e58d0c40c9";

  # libhc: the hypercall.h header the fork's instrumentation includes (normally
  # a git submodule). Provided as a source input instead of initialising it.
  inputs.libhc = {
    url = "github:panda-re/libhc/b2f2efbd948faca9e242ae410e035c0065ec433a";
    flake = false;
  };

  outputs = { self, nixpkgs, libhc }:
    let
      system = "x86_64-linux";
      archMatrix = import ./src/archs.nix;

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnsupportedSystem = true;
      };
      lib = pkgs.lib;

      mkMuslCrossPkgs = archKey:
        import nixpkgs {
          inherit system;
          config.allowUnsupportedSystem = true;
          crossSystem = archMatrix.${archKey}.muslCrossSystem;
        };

      mkBusybox = archKey:
        import ./src/mk-busybox.nix {
          crossPkgs = mkMuslCrossPkgs archKey;
          src = self;
          inherit libhc;
        };
      busyboxBins = lib.mapAttrs (archKey: _: mkBusybox archKey) archMatrix;

      perArchPackages = builtins.listToAttrs (
        lib.mapAttrsToList
          (archKey: _: {
            name = "busybox-${archMatrix.${archKey}.penguinName}";
            value = busyboxBins.${archKey};
          })
          archMatrix
      );

      # dist: the /igloo_static fragment this tool owns -- the per-arch busybox
      # in the melting-pot dir penguin globs (also pulled into /igloo/boot by
      # gen_image). Mirrors penguin-tools mk-dist-root.
      dist = pkgs.runCommand "busybox-dist"
        {
          nativeBuildInputs = with pkgs.buildPackages; [ coreutils ];
        }
        ''
          set -euo pipefail
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList
              (archKey: _:
                let
                  pn = archMatrix.${archKey}.penguinName;
                  busybox = busyboxBins.${archKey};
                in
                ''
                  mkdir -p "$out/${pn}"
                  cp ${busybox}/bin/busybox "$out/${pn}/busybox"
                '')
              archMatrix
          )}
          chmod -R u+w "$out"
        '';
    in
    {
      packages.${system} = perArchPackages // {
        inherit dist;
        default = dist;
      };

      checks.${system} = {
        inherit dist;
      };
    };
}
