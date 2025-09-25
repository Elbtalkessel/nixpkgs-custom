{
  description = "A collection of reusable Nix package definitions and overlays.";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nuenv = {
      url = "https://flakehub.com/f/xav-ie/nuenv/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      nuenv,
      ...
    }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ nuenv.overlays.default ];
        };

      # Helper function to list package names by reading the packages/ directory
      packageNames = builtins.attrNames (builtins.readDir ./packages);

      makePackages =
        system:
        let
          pkgs = pkgsFor system;
        in
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value = pkgs.callPackage ./packages/${name} { };
          }) packageNames
        );
    in
    {
      packages = forAllSystems (system: makePackages system);

      overlays.default =
        _: prev:
        let
          inherit (prev) system;
          pkgs = self.packages.${system};
        in
        builtins.listToAttrs (
          map (p: {
            name = p;
            value = pkgs.${p};
          }) packageNames
        );
    };
}
