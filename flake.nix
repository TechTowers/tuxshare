{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default-linux";
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    systems,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;
    forEachSystem = f: lib.genAttrs (import systems) (system: f pkgsFor.${system});
    pkgsFor = lib.genAttrs (import systems) (
      system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
    );
  in {
    packages = forEachSystem (pkgs: {
      tuxshare = pkgs.callPackage ./nix/package.nix {};
      default = self.packages.${pkgs.system}.tuxshare;
    });

    devShells = forEachSystem (pkgs:
      import ./nix/shell.nix {
        inherit self;
        inherit pkgs;
      });

    checks = forEachSystem (pkgs:
      import ./nix/checks.nix {
        inherit inputs;
        inherit pkgs;
      });
  };
}
