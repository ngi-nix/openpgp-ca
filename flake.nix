{
  description =
    "OpenPGP CA is a tool for managing OpenPGP keys within an organization.";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-20.03";

  # Upstream source tree(s).
  inputs.openpgp-ca-src = {
    url = "git+https://gitlab.com/openpgp-ca/openpgp-ca";
    flake = false;
  };

  outputs = { self, nixpkgs, openpgp-ca-src }:
    let

      # Generate a user-friendly version numer.
      version = builtins.substring 0 8 openpgp-ca-src.lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-darwin" "x86_64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        });

    in {

      # A Nixpkgs overlay.
      overlay = final: prev: rec {
        finalSrc = final.pkgs.runCommand "openpgp-ca-src-with-lock-file" {} ''
          mkdir $out
          ls ${openpgp-ca-src}
          cp -r ${openpgp-ca-src}/* $out
          cp ${./Cargo.lock} $out/Cargo.lock
        '';

        openpgp-ca = with final;
          pkgs.rustPlatform.buildRustPackage {
            name = "openpgp-ca";
            version = "${version}";
	          src = finalSrc;

            buildInputs = [ nettle clang gmp openssl capnproto sqlite gnupg ]
              ++ lib.optionals stdenv.isDarwin
              [ darwin.apple_sdk.frameworks.Security ];

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
              description =
                "OpenPGP CA is a tool for managing OpenPGP keys within an organization.";
            };

            cargoSha256 = "sha256-P8y3Fy6bXTH02omEbPmg5+s+B1ffKtUwxATPPLyNTtk=";

          };

        openpgp-ca-docker = with final;
          pkgs.dockerTools.buildImage {
            name = "openpgp-ca";
            tag = "latest";

            # fromImage = someBaseImage;
            # fromImageName = null;
            # fromImageTag = "latest";

            contents = pkgs.openpgp-ca;
            runAsRoot = ''
              #!${pkgs.runtimeShell}
              mkdir -p /var/run/openpgp-ca
            '';

            config = {
              Cmd = [ "/bin/openpgp-ca" ];
              Env = [ "OPENPGP_CA_DB=/var/run/openpgp-ca/openpgp-ca.sqlite" ];
              WorkingDir = "/var/run/openpgp-ca";
              Volumes = { "/var/run/openpgp-ca" = { }; };
            };
          };
      };

      # Provide some binary packages for selected system types.
      packages =
        forAllSystems (system: { inherit (nixpkgsFor.${system}) openpgp-ca; })
        // {
          x86_64-linux = {
            inherit (nixpkgsFor.x86_64-linux) openpgp-ca openpgp-ca-docker;
          };
        };

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage =
        forAllSystems (system: self.packages.${system}.openpgp-ca);

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems (system: if system == "x86_64-darwin" then {} else {
        inherit (self.packages.${system}) openpgp-ca;

        # Additional tests, if applicable.
        # Test if commands succeed
        openpgp-ca-commands =
          with import (nixpkgs + "/nixos/lib/testing-python.nix") {
            inherit system;
          };
          with self.packages.${system};

          makeTest {
            nodes = {
              machine_a = { ... }: {
                environment.systemPackages = [ openpgp-ca ];
              };
            };

            testScript = ''
              start_all()

              machine_a.execute("openpgp-ca -d /tmp/openpgp-ca.sqlite ca init example.org")
              machine_a.succeed(
                  "openpgp-ca -d /tmp/openpgp-ca.sqlite user add --email alice@example.org --name 'Alice Adams'"
              )
              machine_a.succeed(
                  "openpgp-ca -d /tmp/openpgp-ca.sqlite user add --email bob@example.org --name 'Bob Baker'"
              )
              machine_a.succeed("openpgp-ca -d /tmp/openpgp-ca.sqlite user list")
              machine_a.succeed(
                  "openpgp-ca -d /tmp/openpgp-ca.sqlite user export --email alice@example.org"
              )
              machine_a.succeed("openpgp-ca -d /tmp/openpgp-ca.sqlite wkd export /tmp/export")
              machine_a.succeed("openpgp-ca -d /tmp/openpgp-ca.sqlite ca export")

              machine_a.shutdown()
            '';
          };
      });

    };

}
