# igOS secure-boot signing keys

Secure-boot signing key material is **no longer stored here**. It now lives in a
dedicated private repository:

```
git@github.com:Perle-Systems-Limited/gpgkeys.git
```

`build_iGOS_TMDS64EVM_fs.sh` clones/refreshes that repo on the build host into
`../gpgkeys` (git-ignored) for `igos-*` flavors and passes it to
`vyos-build/build-vyos-image` via `--gpg-signing-key-dir`. build-vyos-image then
discovers the key material **by glob** and stages it for the binary-stage hook
`29-igos-sign-boot.binary`, which GPG detached-signs the **final** kernel +
initrd. The `.sig` files are carried into every installed image by the vyos-1x
installer (`image_installer.py` / `prod_image.py`).

Signing is driven by the per-flavor **`sign_boot`** flag in the build-flavor
TOML (`vyos-build/data/build-flavors/*.toml`; default `false` in
`data/defaults.toml`). `igos-am64x-all` and `igos-am64x-evm` set
`sign_boot = true`.

## Expected files in the gpgkeys repo

The directory is scanned by glob, so exact names may vary as long as they
contain these substrings (exactly one match each is required):

| glob           | contents                                                          |
| -------------- | ----------------------------------------------------------------- |
| `*privatekey*` | ASCII-armored exported GPG **secret** key (passphrase-protected)  |
| `*passphrase*` | the key's passphrase (only the first line is used)                |
| `*pubkey*`     | ASCII-armored exported GPG **public** key (grub enforcement half) |

## No fallback

- `sign_boot = true` + key material present -> kernel + initrd are signed.
- `sign_boot = true` + key material missing/ambiguous -> the build **FAILS**
  (it never ships an unsigned image, and never falls back to a passphrase-less
  key).
- `sign_boot = false` (e.g. `generic`) -> nothing is staged and nothing is
  signed, even if a key dir is supplied.

## Generate a key (one time, in the gpgkeys repo)

```sh
# choose a passphrase and keep it in the passphrase file (no trailing newline)
printf '%s' 'your-strong-passphrase' > secureboot-passphrase

gpg --batch --pinentry-mode loopback --passphrase-file secureboot-passphrase \
    --gen-key <<'EOF'
Key-Type: RSA
Key-Length: 4096
Name-Real: iGOS Secure Boot
Name-Email: secureboot@perle.com
Expire-Date: 0
%commit
EOF

# private half -> used by the build to sign kernel/initrd
gpg --export-secret-keys --armor secureboot@perle.com > secureboot-privatekey.asc

# public half -> embed into the custom grub core (the enforcement half)
gpg --export --armor secureboot@perle.com > secureboot-pubkey.asc
```

Commit `secureboot-privatekey.asc`, `secureboot-pubkey.asc`, and
`secureboot-passphrase` to the private `gpgkeys` repo. Because the whole repo is
secret, storing the passphrase alongside the key is acceptable for automated
builds; for a hardened setup keep the private key on an offline / HSM host and
inject the passphrase into a `*passphrase*` file from your CI secret store at
build time.
