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
            pkgs.git-cliff
            # Text extraction checks of rendered PDFs (ADR 0035).
            pkgs.poppler-utils
            # A second text extractor for the reading-order tests (ADR 0037).
            (pkgs.python3.withPackages (p: [ p.pdfminer-six ]))
            pkgs.just
            pkgs.watchexec
          ];
        };

        # Records the README demo GIF (ADR 0044); not needed otherwise.
        devShells.demo = pkgs.mkShell {
          packages = [
            pkgs.nodejs_22
            pkgs.ffmpeg
            pkgs.just
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
