{
  self,
  pkgs,
}: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      git
    ];

    buildInputs = with pkgs; [
      dart
    ];

    shellHook = ''
      ${self.checks.${pkgs.system}.pre-commit-check.shellHook}
    '';
  };
}
