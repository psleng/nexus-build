# igOS secure-boot signing keys (engineering)

`build_iGOS_TMDS64EVM_fs.sh` passes the key below to
`vyos-build/build-vyos-image` via `--gpg-signing-key` for the secure
(dm-verity) flavors `igos-am64x-all` and `igos-am64x-evm`. The build's
binary-stage hook `29-igos-sign-boot.binary` then GPG detached-signs the
**final** kernel + initrd (after the dm-verity root hash is baked in), and the
`.sig` files are carried into every installed image by the vyos-1x installer
(`image_installer.py` / `prod_image.py`).

## Expected file

```
keys/igos-secure-boot-signing.asc
```

An ASCII-armored, **passphrase-less** exported GPG *secret* key. Automated build
signing cannot answer a passphrase prompt, so a protected key will fail closed.

## Generate an engineering key (one time)

```sh
gpg --batch --gen-key <<'EOF'
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: iGOS Secure Boot (engineering)
Name-Email: secureboot-eng@perle.com
Expire-Date: 0
%commit
EOF

# private half -> used here by the build to sign kernel/initrd
gpg --export-secret-keys --armor secureboot-eng@perle.com \
    > keys/igos-secure-boot-signing.asc

# public half -> embed into the custom grub core (the enforcement half)
gpg --export --armor secureboot-eng@perle.com \
    > keys/igos-secure-boot-signing.pub.asc
```

## Behavior

- Key present -> kernel + initrd are signed (secure build).
- Key absent  -> build still succeeds but kernel/initrd are **UNSIGNED** (the
  hook self-gates and warns). Non-verity flavors never sign.

## At release

Replace `igos-secure-boot-signing.asc` with a **symlink** to the production key
(kept on the offline / HSM signing host). Nothing in the build scripts changes.
