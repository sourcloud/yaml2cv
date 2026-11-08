{
  description = "yaml2cv - render YAML CVs to PDF";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        beamPackages = pkgs.beam29Packages;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            beamPackages.erlang
            beamPackages.rebar3
            pkgs.gleam
            pkgs.typst
            pkgs.just
            pkgs.watchexec
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
