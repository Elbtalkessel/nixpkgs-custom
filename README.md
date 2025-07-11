## A collection of reusable Nix package definitions and overlays

## Task to do

- Automatic version updates.

## Usage

- `nix run ./#<name>`
- Using overlay:

```nix
{
    inputs = {
        nixpkgs = {
            url = "github:nixos/nixpkgs/nixos-unstable";
        };
        nixpkgs-custom = {
            url = "github:Elbtalkessel/nixpkgs-custom/master";
        };
    };

    outputs = { nixpkgs, nixpkgs-custom }:
    let
        pkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = [
                nixpkgs-custom.overlays.default
            ];
        };
    in
    {
        homeConfigurations.yourusername = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [
                home.packages = [
                    pkgs.usbdrivetools
                ];
            ];
        };
    };
}
```
