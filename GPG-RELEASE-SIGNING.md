# GPG Release Signing Setup

The release workflow automatically signs release tarballs with GPG if configured.

## Setup (One-Time)

### 1. Export Your GPG Private Key

```bash
# List your keys
gpg --list-secret-keys --keyid-format LONG

# Export the private key (use your key ID)
gpg --export-secret-keys --armor B71E4769AE500472 > private-key.asc
```

### 2. Add to GitHub Secrets

Go to: `https://github.com/remenoscodes/git-native-issue/settings/secrets/actions`

Add two secrets:

**GPG_PRIVATE_KEY:**
- Copy the entire contents of `private-key.asc`
- Include the `-----BEGIN PGP PRIVATE KEY BLOCK-----` and `-----END PGP PRIVATE KEY BLOCK-----` lines

**GPG_PASSPHRASE:** (if your key has a passphrase)
- Enter your GPG key passphrase
- If your key has no passphrase, you can skip this secret

### 3. Delete the Exported Key (Important!)

```bash
rm private-key.asc
```

Never commit the private key to git or leave it on disk.

## How It Works

When you push a tag (e.g., `v1.0.2`):

1. Workflow creates release tarball
2. Imports GPG key from secret
3. Signs tarball with `gpg --armor --detach-sign`
4. Uploads both tarball and `.asc` signature to release

## Verification (Users)

Users can verify releases:

```bash
# Download release
curl -LO https://github.com/remenoscodes/git-native-issue/releases/download/v1.0.1/git-native-issue-v1.0.1.tar.gz
curl -LO https://github.com/remenoscodes/git-native-issue/releases/download/v1.0.1/git-native-issue-v1.0.1.tar.gz.asc

# Import public key
gpg --keyserver keys.openpgp.org --recv-keys B71E4769AE500472

# Verify signature
gpg --verify git-native-issue-v1.0.1.tar.gz.asc git-native-issue-v1.0.1.tar.gz
```

Good signature output:
```
gpg: Good signature from "Emerson Soares <remenoscodes@gmail.com>"
```

## Fallback

If secrets are not configured, the workflow still works but skips signing:
- Release is created
- Tarball is uploaded
- No `.asc` signature file
- Warning logged: "GPG_PRIVATE_KEY secret not set - skipping signature"

## Public Key

Your public key should be published to keyservers:

```bash
gpg --keyserver keys.openpgp.org --send-keys B71E4769AE500472
gpg --keyserver keyserver.ubuntu.com --send-keys B71E4769AE500472
```

Users can also find it in your GitHub profile or in the repository.
