# Flake: openpgp-ca

This flake provides openpgp-ca, build from the most recent sources available today.

The openpgp-ca is exported as default package and  as `openpgp-ca` attribute.

Provided are builds for both linux and macos.

## Updating

As currently `Cargo.lock` is `.gitignore`d upstream, a patch locking the dependencies declared in upstream's `Cargo.toml` is included and must be updated together with the sources. The update process thus includes creating an updated patch first.

```
$ nix-shell
$ (shell) pushd <path to repo>
$ (shell) cargo generate-lockfile
$ (shell) git diff --no-index -- /dev/null  Cargo.lock > Cargo.lock.patch
$ (shell) popd
$ (shell) exit
$ mv <path to repo>/Cargo.lock.patch 0001-Cargo.lock.patch
$ nix flake update
```

Note: this should no longer be necessary as upstream starts including that lockfile.
