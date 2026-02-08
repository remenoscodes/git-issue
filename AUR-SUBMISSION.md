# AUR Submission Guide

**Package**: git-issue
**Version**: 1.0.1
**Date**: 2026-02-08

---

## Prerequisites

1. **AUR Account**: https://aur.archlinux.org/register
2. **SSH Key**: Added to AUR account
3. **Arch Linux**: For testing (can use Docker)

---

## PKGBUILD Validation

### Local Testing

```bash
# Test PKGBUILD locally
cd ~/source/remenoscodes.git-issue

# Validate PKGBUILD syntax
namcap PKGBUILD

# Build package
makepkg -si

# Test installation
git-issue version  # Should show 1.0.1
```

### Docker Testing (Ubuntu/Other Systems)

```bash
# Use Arch Linux container
docker run --rm -it archlinux:latest bash

# Inside container:
pacman -Syu --noconfirm base-devel git
useradd -m builder
su - builder

# Copy PKGBUILD and build
# (mount or copy PKGBUILD into container)
makepkg -si
```

---

## Submission Steps

### 1. Clone AUR Repository

```bash
git clone ssh://aur@aur.archlinux.org/git-issue.git aur-git-issue
cd aur-git-issue
```

### 2. Add Package Files

```bash
# Copy PKGBUILD
cp ~/source/remenoscodes.git-issue/PKGBUILD .

# Generate .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# Review files
cat PKGBUILD
cat .SRCINFO
```

### 3. Commit and Push

```bash
# Add files
git add PKGBUILD .SRCINFO

# Commit
git commit -m "Initial release: git-issue 1.0.1

Distributed issue tracking system built on Git.

Features:
- Store issues as Git commits in refs/issues/*
- Bidirectional sync with GitHub Issues
- Offline-first, distributed workflow
- Full Git history and merging
- Format specification (ISSUE-FORMAT.md)

Upstream: https://github.com/remenoscodes/git-issue"

# Push to AUR
git push origin main
```

---

## Post-Submission

### Package URL
https://aur.archlinux.org/packages/git-issue

### Installation (Users)
```bash
# Using yay
yay -S git-issue

# Using paru
paru -S git-issue

# Manual
git clone https://aur.archlinux.org/git-issue.git
cd git-issue
makepkg -si
```

### Maintenance

#### Update Version

When releasing a new version (e.g., v1.0.2):

```bash
cd aur-git-issue

# Update PKGBUILD
# - Change pkgver=1.0.2
# - Update sha256sums (get from GitHub release)
# - Increment pkgrel=1 (or reset to 1 for new version)

# Regenerate .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# Commit and push
git add PKGBUILD .SRCINFO
git commit -m "Update to 1.0.2"
git push origin main
```

#### Respond to Comments

Monitor package page for:
- Orphan requests
- Out-of-date flags
- User comments/issues

---

## Troubleshooting

### Issue: SHA256 Mismatch

**Problem**: `sha256sums` doesn't match downloaded tarball

**Solution**:
```bash
# Download tarball
curl -LO https://github.com/remenoscodes/git-issue/releases/download/v1.0.1/git-issue-v1.0.1.tar.gz

# Compute SHA256
sha256sum git-issue-v1.0.1.tar.gz

# Update PKGBUILD with correct hash
```

### Issue: Build Fails

**Problem**: `makepkg` fails during build

**Solution**:
```bash
# Clean build directory
rm -rf src/ pkg/ *.tar.gz

# Try again with verbose output
makepkg -si --noconfirm

# Check specific error and fix PKGBUILD
```

### Issue: Package Not Found

**Problem**: `yay -S git-issue` says package not found

**Solution**: AUR takes a few minutes to index new packages. Wait 5-10 minutes after initial push.

---

## Best Practices

### Version Numbering
- `pkgver`: Upstream version (1.0.1)
- `pkgrel`: Package release (1 for first AUR release, increment for PKGBUILD fixes)

### Dependencies
- `depends`: Required at runtime (git, jq)
- `optdepends`: Optional features (github-cli for bridge)
- `makedepends`: Build-time only (we don't need any)

### File Permissions
- Binaries: 755 (`install -m755`)
- Documentation: 644 (`install -m644`)

### Testing
Always test before pushing:
```bash
makepkg -si
git-issue version
git-issue --help
```

---

## References

- [AUR Submission Guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines)
- [PKGBUILD Reference](https://wiki.archlinux.org/title/PKGBUILD)
- [makepkg Manual](https://man.archlinux.org/man/makepkg.8)
- [namcap Tool](https://wiki.archlinux.org/title/Namcap)

---

**Last Updated**: 2026-02-08
**Maintainer**: Emerson Soares (remenoscodes@gmail.com)
