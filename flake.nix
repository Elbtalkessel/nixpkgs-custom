{
  description = "A collection of reusable Nix package definitions and overlays.";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          usbdrivetools = pkgs.callPackage ./usbdrivetools { };
          bootdev = pkgs.callPackage ./bootdev { };
        }
      );
      overlays.default = final: prev: {
        inherit (self.packages.${prev.system}) usbdrivetools;
        inherit (self.packages.${prev.system}) bootdev;
      };
    };
}
