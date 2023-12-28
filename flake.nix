{
  description = "The Literate Markdown Tangle tool";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    gomod2nix = {
      url = "github:tweag/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = ( 
    { self, nixpkgs, flake-utils, gomod2nix }:
      flake-utils.lib.eachDefaultSystem (system:
        let
          lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";
          version = builtins.substring 0 8 lastModifiedDate;
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ gomod2nix.overlays.default ];
          };
        in 
        {
          packages = {
            lmt = pkgs.buildGoApplication {
              pname = "lmt";
              inherit version;
              src = ./.;
              vendorHash = null;
              modules = ./gomod2nix.toml;
            };
          };

          devShell = pkgs.mkShell {
            buildInputs = with pkgs; [
              go
              gopls
              gotools
              go-tools
              gomod2nix.packages.${system}.default
            ];
          };

          defaultPackage = self.packages.${system}.lmt;
        }
      )
  );
}
