## A collection of reusable Nix package definitions and overlays.

- [usbdrivetools](https://github.com/satk0/usbdrivetools)
- [bootdev](https://github.com/bootdotdev/bootdev)

## Usage examples

Using Home-Manager

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
