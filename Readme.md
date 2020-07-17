# Flake: openpgp-ca

This flake provides openpgp-ca, build from the most recent sources available today.

The openpgp-ca is exported as default package and  as `openpgp-ca` attribute.

Provided are builds for both linux and macos.

## Update instructions

To update the flake to track new releases of `openpgp-ca` run:

```
$ nix flake update --update-input openpgp-ca-src
```

then update the `cargoSha256`.

To update the dependencies used, i.e. the nixpkgs version, run

```
$ nix flake update --update-input nixpkgs
```

or run

```
$ nix flake update --recreate-lock-file
```

to update everything.
