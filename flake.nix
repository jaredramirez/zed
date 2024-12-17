{
  description =
    "High-performance, multiplayer code editor from the creators of Atom and Tree-sitter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    flake-compat.url = "github:edolstra/flake-compat";

    # Needed until swift 6 is available in nixpkgs
    swift_6.url = "github:timothyklim/swift-flake";
  };

  outputs = { nixpkgs, rust-overlay, crane, swift_6, ... }:
    let
      systems =
        [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      overlays = {
        rust-overlay = rust-overlay.overlays.default;
        rust-toolchain = final: prev: {
          rustToolchain =
            final.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        };
        zed-editor = final: prev: {
          zed-editor = final.callPackage ./nix/build.nix {
            crane = crane.mkLib final;
            rustToolchain = final.rustToolchain;
          };
        };
        swift = final: prev: {
          swift = swift_6.packages.${prev.system}.default;
        };
      };

      mkPkgs = system:
        import nixpkgs {
          inherit system;
          overlays = builtins.attrValues overlays;
        };

      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f (mkPkgs system));
    in {
      packages = forAllSystems (pkgs: {
        zed-editor = pkgs.zed-editor;
        default = pkgs.zed-editor;
      });

      devShells = forAllSystems (pkgs:
        let craneLib = crane.mkLib pkgs;
        in {
          default = craneLib.devShell {
            # Automatically inherit any build inputs from `zed-editor`
            inputsFrom = [ pkgs.zed-editor ];

            # Any additional dev deps
            packages = [ pkgs.rust-analyzer ];

            # Set any necessary env variables
            BINDGEN_EXTRA_CLANG_ARGS = "--sysroot=$(xcrun --show-sdk-path)";
            BUILD_LIBRARY_FOR_DISTRIBUTION = "YES";
          };
        });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);

      overlays = overlays // {
        default =
          nixpkgs.lib.composeManyExtensions (builtins.attrValues overlays);
      };
    };
}
