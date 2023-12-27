# About Nix
Nix is a package manager designed to allow for completely reproducible builds. It allows for developers to have reproducible build environments in order to ensure consistency. For more information, see <https://nixos.org/>.

# Nix Flakes

A flake is simply a source tree (such as a Git repository) containing a file named `flake.nix` that provides a standardized interface to Nix artifacts such as packages or NixOS modules. Flakes can have dependencies on other flakes, with a “lock file” pinning those dependencies to exact revisions to ensure reproducible evaluation.

Flakes are written in the nix language and, at the very least, they must have

* A `description` attribute. which is a one-line description shown by `nix flake metadata`.
* An `inputs` attribute, which specifies other flakes that this flake depends on. These are fetched by Nix and passed as arguments to the `outputs` function.
* An `outputs` attribute, which is the heart of the flake: it’s a function that produces an attribute set. The function arguments are the flakes specified in `inputs`.

# The LMT flake

The purpose of this literate flake is to "flakify" the LMT distribution.

We start with a description
```nix flake.nix+=
{
  description = "The Literate Markdown Tangle tool";

```

We'll grab the `go` compiler from the `nixpkgs` repository, so the url of the unstable version of that repository becomes our first input. We'll also use the `flake-utils` to deal with the boring per-platform attribute sets and `gomod2nix` to generate Nix compatible hashes of Go packages.
```nix flake.nix+=
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    gomod2nix = {
      url = "github:tweag/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

```

The action all goes on in the `outputs` attribute. This is a function whose single argument is the `inputs` attribute set (dictionary) but with an extra entry with key `self` to refer to the current flake. We can access entries in that set by pattern matching on their keys.
```nix flake.nix+=
  outputs = { self, nixpkgs, flake-utils, gomod2nix }:
```

The expression before the `:` is the pattern we are matching, which in this case binds variables `self`, `nixpkgs`, `utils` and `gomod2nix` to the values of the correspondingly keyed entries of the argument in the body, which follows. 

This flake applies to any of the platforms, so use the `eachDefaultSystem` function from the `flake-utils` module to instantiate it for each supported platform. 
```nix flake.nix+=
    flake-utils.lib.eachDefaultSystem (system:
```

Now LMT doesn't appear to have a version number, so we'll generate a user-friendly one from the date that the source was last modified. When working out that date we are careful to be backward compatible with older versions of flakes.
```nix flake.nix+=
      let
        lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";
        version = builtins.substring 0 8 lastModifiedDate;
```

We also import `nixpkgs` here, adding support for `gomod2nix` by applying it as an *overlay*.
```nix flake.nix+=
        pkgs = import nixpkgs {
  	  inherit system;
  	  overlays = [ gomod2nix.overlays.default ];
        };
      in 
      {
```

Now we get to the meat of the matter, an attribute to provide a binary packages of LMT. The `gomod2nix.toml` file is generated and contains ??? 
```nix flake.nix+=
        packages = {
          lmt = pkgs.buildGoModule {
            pname = "lmt";
            inherit version;
            src = ./.;
            vendorHash = null;
            modules = ./gomod2nix.toml;
          };
        };

```

We also provide a development shell attribute which exposes the `gomod2nix` tool.
```nix flake.nix+=
	devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            go
            gopls
            gotools
            go-tools
            gomod2nix.packages.${system}.default
          ];
        };

```

And finally, declare the default package for `nix build`.
```nix flake.nix+=
        defaultPackage = self.packages.${system}.lmt;
      }
    );
```

Fin!
```nix flake.nix+=
}
```


