{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    devenv.url = "github:cachix/devenv";
    nixpkgs-python.url = "github:cachix/nixpkgs-python";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = {
    self,
    nixpkgs,
    devenv,
    systems,
    ...
  } @ inputs: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    packages = forEachSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      devenv-up = self.devShells.${system}.default.config.procfileScript;
      devenv-test = self.devShells.${system}.default.config.test;
      tuxshare = pkgs.callPackage ./nix/package.nix {};
      default = self.packages.${system}.tuxshare;
    });

    devShells =
      forEachSystem
      (system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              packages = with pkgs; [
                git # duh
              ];

              languages = {
                dart.enable = true;
              };

              pre-commit.hooks = {
                dart-analyze.enable = true;
                dart-format.enable = true;
              };

              enterShell =
                # bash
                ''
                  tput setaf 2; tput bold; echo "git version"; tput sgr0
                  git --version
                  tput setaf 2; tput bold; echo "flutter version"; tput sgr0
                  dart --version
                '';
            }
          ];
        };
      });
  };
}
