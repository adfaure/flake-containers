{
  description = "A flake module to compose nixos systemd-nspawn containers.";
  outputs = { self, ... }: {
    flakeModules.default = ./flake-module.nix;
    flakeModule = self.flakeModules.default;
  };
}
