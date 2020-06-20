{
  description = "OpenPGP CA is a tool for managing OpenPGP keys within an organization.";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-20.03";

  # Upstream source tree(s).
  inputs.openpgp-ca-src = { url = "git+https://gitlab.com/openpgp-ca/openpgp-ca"; flake = false; };

  outputs = { self, nixpkgs, openpgp-ca-src }:
    let

      # Generate a user-friendly version numer.
      version = builtins.substring 0 8 openpgp-ca-src.lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-darwin" "x86_64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        openpgp-ca = with final; pkgs.rustPlatform.buildRustPackage {
          name = "openpgp-ca";
          version = "${version}";
          src = openpgp-ca-src;
          patches = [./0001-Add-lock-file.patch];

          buildInputs = [ nettle clang gmp openssl capnproto sqlite gnupg]
          ++ lib.optionals stdenv.isDarwin [ darwin.apple_sdk.frameworks.Security ]
          ;

          nativeBuildInputs = with pkgs; [ pkg-config ];

          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang}/lib";

          # Tests require setting up a gpg keychain in a nonstandard temporary
          # `homedir`. This currently fails (on  my  machine) on gnupg's end
          # such that those tests do not succeed.
          # Following tests will fail:
          #
          # [
          #   test_alice_authenticates_bob_centralized
          #   test_alice_authenticates_bob_decentralized
          #   test_bridge
          # ];
          doCheck = false;

          meta = {
            homepage = "https://openpgp-ca.gitlab.io/openpgp-ca/";
            description = "OpenPGP CA is a tool for managing OpenPGP keys within an organization.";
          };

          cargoSha256 = "sha256-P8y3Fy6bXTH02omEbPmg5+s+B1ffKtUwxATPPLyNTtk=";

        };

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) hello;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.hello);

      # A NixOS module, if applicable (e.g. if the package provides a system service).
      nixosModules.hello =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];

          environment.systemPackages = [ pkgs.hello ];

          #systemd.services = { ... };
        };

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems (system: {
        inherit (self.packages.${system}) hello;

        # Additional tests, if applicable.
        test =
          with nixpkgsFor.${system};
          stdenv.mkDerivation {
            name = "hello-test-${version}";

            buildInputs = [ hello ];

            unpackPhase = "true";

            buildPhase = ''
              echo 'running some integration tests'
              [[ $(hello) = 'Hello, world!' ]]
            '';

            installPhase = "mkdir -p $out";
          };

        # A VM test of the NixOS module.
        vmTest =
          with import (nixpkgs + "/nixos/lib/testing-python.nix") {
            inherit system;
          };

          makeTest {
            nodes = {
              client = { ... }: {
                imports = [ self.nixosModules.hello ];
              };
            };

            testScript =
              ''
                start_all()
                client.wait_for_unit("multi-user.target")
                client.succeed("hello")
              '';
          };
      });

    };
}
