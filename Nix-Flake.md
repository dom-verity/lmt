# Literate Markdown Tangle as a Nix flake 

Nix is a package manager designed to allow for completely reproducible builds. It allows for developers to have reproducible build environments in order to ensure consistency. For more information, see <https://nixos.org/>.

## Nix Flakes

A flake is simply a source tree (such as a Git repository) containing a file named `flake.nix` that provides a standardized interface to Nix artifacts such as packages or NixOS modules. Flakes can have dependencies on other flakes, with a “lock file” pinning those dependencies to exact revisions to ensure reproducible evaluation.

Flakes are written in the nix language and take the form of an *attribute set* with, at least, the followimng top level structure

```nix flake.nix+=
{
  description = "The Literate Markdown Tangle tool";

  inputs = {
    <<<input attributes>>>
  };

  outputs = ( 
    <<<output function>>>
  );
}
```

containing the following attributes:

* `description` a one-line description shown by `nix flake metadata`.
* `inputs` which specifies other flakes that this flake depends on. These are fetched by Nix and passed as arguments to the `outputs` function.
* `outputs` which is the heart of the flake: it’s a function that produces an attribute set. This is passed a single argument, an attribute list comprising the attributes specified in `inputs` plus an attribute `self` which refers to the current flake.

## The LMT flake

The purpose of this literate flake, which will be *tangled* to produce the file `flake.nix` in the root directory of this project, is to "flakify" the LMT distribution. It will orchestrate the process of pulling in the tools needed to build the application (Go and friends), execute the build itself and place the resulting application into the Nix *store* along with any associated support files.

### Usage

Once our project has been flakified it will make LMT available for inclusion in any Nix build. Assuming that you have a flakified version of Nix installed, it can be built and added to the Nix store by issuing the command
```bash
  nix build
```
from the root of the LMT project. If successful, this leaves a link to the constructed target tree, called `result`, in the current directory. We can also build directly from the Github repository with the command
```bash
  nix build github:dom-verity/lmt
```
which again adds the tree of constructed artefacts to the Nix store and leaves a `result` link in the current directory.

To run LMT directly from the Nix store we can issue the command
```bash
  nix run .#lmt <Literate Code>.md
```
from the current directory or the command
```bash
  nix run github:dom-verity/lmt <Literate Code>.md
```
from anywhere. This will check to see if the latest version of the complied project is in the Nix store, and if it isn't it will automatically build and add it to the store.

Finally, to enter a development environment that makes available all of the tools and libraries needed to build LMT, we can use the command
```
   nix develop
```
from the root of the LMT project or the command
```
   nix develop github:dom-verity/lmt
```
from anywhere.

### The `inputs` attribute

We'll grab the required build tools from the `nixpkgs` repository, so the url of the unstable version of that repository becomes our first input. We'll also use the `flake-utils` module to deal with boring per-platform attribute sets and `gomod2nix` to generate Nix compatible hashes of Go packages. So we define the following attributes in the body of the `inputs` attribute of the flake template above:
```nix "input attributes"+=
nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
flake-utils.url = "github:numtide/flake-utils";

gomod2nix = {
  url = "github:tweag/gomod2nix";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-utils.follows = "flake-utils";
};
```

### The `outputs` attribute

The action all goes on in the `outputs` attribute. This is a function whose single argument is the `inputs` attribute set, specified in the last section, but with an extra entry with key `self` to refer to the current flake. We can access entries in that set by pattern matching on their keys.
```nix "output function"+=
{ self, nixpkgs, flake-utils, gomod2nix }:
```
The expression before the `:` is the pattern we are matching, which in this case binds variables `self`, `nixpkgs`, `utils` and `gomod2nix` to the values of the correspondingly keyed entries of the argument in the body, which follows. 

This flake applies to any of the platforms, so use the `eachDefaultSystem` function from the `flake-utils` module to instantiate it for each supported platform.
```nix "output function"+=
  flake-utils.lib.eachDefaultSystem (system:
```
The `system:` phrase, at the end of this line, is the head of a function with parameter `system` and whose body follows, and whose extent is delimited by surrounding parentheses `()`. The function `eachDefaultSystem` will execute that function once for each supported platform, passing it a string identifying that platform - `"x86_64-linux"`, `"aarch64-darwin"` etc.

Now LMT doesn't appear to have a version number, so we'll generate a user-friendly one from the date that the source was last modified. When working out that date we are careful to be backward compatible with older versions of flakes.
```nix "output function"+=
    let
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";
      version = builtins.substring 0 8 lastModifiedDate;
```
We also import `nixpkgs` here, adding support for `gomod2nix` by applying it as an *overlay*.
```nix "output function"+=
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ gomod2nix.overlays.default ];
      };
    in 
    {
```

Now we get to the meat of the matter, an attribute to build and package the LMT binary. This uses the `buildGoApplication` function provided in the `nixpkgs` repository. 
```nix "output function"+=
      packages = {
        lmt = pkgs.buildGoApplication {
          pname = "lmt";
          inherit version;
          src = ./.;
          vendorHash = null;
          modules = ./gomod2nix.toml;
        };
      };

```
The `gomod2nix.toml` file, referered to in the `modules` attribute, is generated from the `go.mod` module file using the `gomod2nix` tool, provided in the Nix development environment for this project. It contains Nix compatible hashes of the Go libaries which the build depends on. In this case, our project doesn't pull in any external libraries and so this file is largely trivial.  

We also provide a development shell attribute which provides the various Go build tools and the `gomod2nix` tool
```nix "output function"+=
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
and declare the default package for `nix build`.
```nix "output function"+=
      defaultPackage = self.packages.${system}.lmt;
    }
```
Finally, the function passed to `eachDefaultSystem` ends here.
```nix "output function"+=
  )
```

# Fin!
