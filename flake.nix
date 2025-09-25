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
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          usbdrivetools = pkgs.callPackage ./packages/usbdrivetools { };
          bootdev = pkgs.callPackage ./packages/bootdev { };
          ollama-copilot = pkgs.callPackage ./packages/ollama-copilot { };
          sddm-themes = pkgs.callPackage ./packages/sddm-themes { };
          tlm = pkgs.callPackage ./packages/tlm { };
          waifu = pkgs.callPackage ./packages/waifu { };
        }
      );
      overlays.default = _: prev: {
        inherit (self.packages.${prev.system}) usbdrivetools;
        inherit (self.packages.${prev.system}) bootdev;
        inherit (self.packages.${prev.system}) ollama-copilot;
        inherit (self.packages.${prev.system}) sddm-themes;
        inherit (self.packages.${prev.system}) tlm;
        inherit (self.packages.${prev.system}) waifu;
      };
    };
}
