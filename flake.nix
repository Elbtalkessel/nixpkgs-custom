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
      _ = builtins;

      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ nuenv.overlays.default ];
        };

      # Packages structure as follows:
      # packages/
      #   <package-group>/
      #     <package-name>/
      #       default.nix
      # Read children directory function reads a given path (./packages)
      # and returns an absolute paths to each <package-name>/
      rcd =
        p:
        _.readDir p
        |> nixpkgs.lib.filterAttrs (_: val: val == "directory")
        |> _.attrNames
        |> map (v: nixpkgs.lib.path.append p v);
      pp = rcd ./packages |> map rcd |> nixpkgs.lib.flatten;

      makePackages =
        system:
        let
          pkgs = pkgsFor system;
        in
        _.listToAttrs (
          map (p: {
            name = (_.baseNameOf p);
            value = pkgs.callPackage p { };
          }) pp
        );
    in
    {
      packages = forAllSystems (system: makePackages system);

      overlays.default =
        _: prev:
        let
          inherit (prev.stdenv.hostPlatform) system;
          pkgs = self.packages.${system};
        in
        builtins.listToAttrs (
          map (p: {
            name = (_.baseNameOf p);
            value = pkgs.${p};
          }) pp
        );
    };
}
