# Installation Strategy & Distribution Plan

**Date**: 2026-02-08
**Status**: Implementation in progress

---

## Decision: In-Repo Homebrew Formula ✅

After analyzing the pros/cons, we're using **Option 1: In-Repo Formula**.

### Why In-Repo?

✅ **Single source of truth** - formula lives with code
✅ **Atomic version updates** - version bump happens in same commit
✅ **Simpler maintenance** - no separate homebrew-tap repo to sync
✅ **Standard practice** - ripgrep, bat, fd, exa all do this
✅ **Direct installation** - users can `brew install remenoscodes/git-issue/git-issue`

### What We're NOT Doing

❌ Separate `homebrew-tap` repository (unnecessary for single tool)
❌ Non-standard naming (the repo is `git-issue`, not `git-issue-brew`)

### How It Works

Users install with:
```bash
brew tap remenoscodes/git-issue
brew install git-issue

# Or one-liner:
brew install remenoscodes/git-issue/git-issue
```

Homebrew supports tapping any repo with a `Formula/` directory, not just `homebrew-*` repos.

---

## Implementation Status

### ✅ Completed (Week 3)

| Method | File | Status |
|--------|------|--------|
| **Makefile** | `Makefile` | ✅ Already exists, well-structured |
| **Install script** | `install.sh` | ✅ Created, executable |
| **Homebrew formula** | `Formula/git-issue.rb` | ✅ Created (in-repo) |
| **README** | `README.md` | ✅ Updated with all methods |
| **GitHub Releases** | - | ✅ v1.0.0 exists, will update for v1.0.1 |

### ⏳ Planned (Month 1)

| Method | Effort | Impact | Priority |
|--------|--------|--------|----------|
| **AUR (Arch)** | Low (2hrs) | High (Arch users love CLI tools) | 🔥 High |
| **asdf plugin** | Low (4hrs) | Medium (developer tool users) | 🔥 High |
| **Test install.sh** | Low (1hr) | High (POSIX users) | 🔥 High |

### ⏳ Planned (Month 2-3)

| Method | Effort | Impact | Priority |
|--------|--------|--------|----------|
| **Nix package** | Medium (8hrs) | Medium (NixOS users) | Medium |
| **Auto-detect installer** | Medium (6hrs) | Medium (UX improvement) | Medium |

### ⏳ Deferred (Month 4+)

| Method | Effort | Impact | Priority |
|--------|--------|--------|----------|
| **.deb (Debian/Ubuntu)** | High (16hrs) | High | If user demand |
| **.rpm (Fedora/RHEL)** | High (16hrs) | Medium | If user demand |
| **Snap** | Low (4hrs) | Low (controversial UX) | ❌ Skip |

---

## Installation Methods Breakdown

### 1. Homebrew (In-Repo) 🍺

**File**: `Formula/git-issue.rb`
**Target**: macOS/Linux users
**Usage**:
```bash
brew install remenoscodes/git-issue/git-issue
```

**Maintenance**: Update formula SHA256 + version on each release

**Pros**:
- ✅ Standard tool for macOS developers
- ✅ Automatic updates via `brew upgrade`
- ✅ Dependency management (ensures `git` is installed)
- ✅ Wide adoption (Homebrew is #1 macOS package manager)

**Cons**:
- ❌ Only works on macOS/Linux
- ❌ Requires updating SHA256 hash for each release

**Priority**: 🔥 **Critical** (primary install method for macOS users)

---

### 2. Install Script 📜

**File**: `install.sh`
**Target**: Any POSIX system (Linux, macOS, BSD, WSL)
**Usage**:
```bash
curl -sSL https://raw.githubusercontent.com/remenoscodes/git-issue/main/install.sh | sh
```

**Maintenance**: Update if directory structure changes

**Pros**:
- ✅ Zero dependencies (pure POSIX shell)
- ✅ Works on ANY Unix-like system
- ✅ Can install to user directory (no sudo)
- ✅ Simple curl one-liner

**Cons**:
- ❌ Requires trusting the script (can be mitigated by reading first)
- ❌ No automatic updates

**Priority**: 🔥 **Critical** (fallback for all non-Homebrew users)

---

### 3. Makefile 🔨

**File**: `Makefile`
**Target**: Developers comfortable with make
**Usage**:
```bash
make install          # System-wide
make install prefix=~ # User install
```

**Maintenance**: Already stable, rarely needs updates

**Pros**:
- ✅ Standard Unix convention
- ✅ Supports `DESTDIR` for packagers
- ✅ Flexible (custom `prefix`, `bindir`, `mandir`)
- ✅ Developer-friendly

**Cons**:
- ❌ Requires cloning the full repo
- ❌ No automatic updates

**Priority**: ✅ **Essential** (standard for Unix tools)

---

### 4. AUR (Arch User Repository) 📦

**File**: `PKGBUILD` (created for AUR submission)
**Target**: Arch Linux / Manjaro / EndeavourOS users
**Usage**:
```bash
yay -S git-issue
paru -S git-issue
```

**Maintenance**: Update PKGBUILD on each release (5 min)

**Pros**:
- ✅ Arch users expect ALL tools to be in AUR
- ✅ Automatic updates via AUR helpers
- ✅ Very low effort (just a PKGBUILD file)
- ✅ High adoption among CLI tool enthusiasts

**Cons**:
- ❌ Only works on Arch-based distros

**Priority**: 🔥 **High** (Arch users are CLI power users - perfect audience)

---

### 5. asdf Plugin 🔧

**Repo**: `remenoscodes/git-issue-asdf` (separate repo)
**Target**: Developers using asdf version manager
**Usage**:
```bash
asdf plugin add git-issue https://github.com/remenoscodes/git-issue-asdf
asdf install git-issue latest
asdf global git-issue 1.0.1
```

**Maintenance**: Update plugin when install method changes (rare)

**Pros**:
- ✅ asdf users manage ALL tools this way (Node, Ruby, Python, etc.)
- ✅ Version pinning (can have multiple versions)
- ✅ Project-specific versions (`.tool-versions`)
- ✅ Developer-friendly

**Cons**:
- ❌ Requires separate plugin repo
- ❌ Only useful for developers using asdf

**Priority**: ✅ **Medium-High** (asdf users love CLI tools)

---

### 6. Nix Package 🐉

**File**: `default.nix` or submit to nixpkgs
**Target**: NixOS / nix-darwin users
**Usage**:
```bash
nix-env -iA nixpkgs.git-issue
```

**Maintenance**: Update nix expression on release (or nixpkgs maintains it)

**Pros**:
- ✅ Nix users are very technical (perfect audience)
- ✅ Reproducible builds
- ✅ Works on NixOS + macOS via nix-darwin
- ✅ Growing community

**Cons**:
- ❌ Requires learning Nix syntax
- ❌ Smaller user base than Homebrew

**Priority**: ✅ **Medium** (after AUR + asdf)

---

### 7. Debian/Ubuntu .deb 📦

**Effort**: High (requires packaging, repo setup)
**Target**: Debian/Ubuntu users
**Usage**:
```bash
sudo dpkg -i git-issue_1.0.1_all.deb
```

**Pros**:
- ✅ Large user base (Ubuntu is #1 desktop Linux)
- ✅ Standard package management

**Cons**:
- ❌ High effort (packaging rules, lintian checks)
- ❌ Requires PPA or upload to debian repos
- ❌ Makefile + install.sh already work fine on Debian/Ubuntu

**Priority**: ⏳ **Deferred** (only if users request it)

---

### 8. Fedora/RHEL .rpm 📦

**Effort**: High
**Target**: Fedora/RHEL/CentOS users
**Usage**:
```bash
sudo rpm -i git-issue-1.0.1.noarch.rpm
```

**Pros**:
- ✅ Standard for RedHat ecosystem
- ✅ COPR (Fedora's PPA) is available

**Cons**:
- ❌ High effort (spec file, rpmlint)
- ❌ Smaller CLI tool user base than Arch/Ubuntu

**Priority**: ⏳ **Deferred** (only if Fedora users request it)

---

### 9. Snap ❌ SKIP

**Why skipping**:
- ❌ Slow startup (snaps use squashfs, noticeable delay)
- ❌ Controversial in community (not loved by CLI users)
- ❌ Confinement issues (git-issue needs to access .git dirs)
- ❌ Flatpak is better for GUI apps, not CLI tools

**Priority**: ❌ **Not Recommended**

---

## Priority Matrix (Effort vs Impact)

```
High Impact
    │
    │  [Homebrew] ✅     [install.sh] ✅
    │      (in-repo)         (POSIX)
    │
    │                    [AUR] ⏳
    │  [Makefile] ✅       (Arch)
    │
    │                   [asdf] ⏳
    │                  (devtools)
    │
    │              [Nix] ⏳     [.deb] ⏳
    │             (NixOS)      (Ubuntu)
    │
    │                        [.rpm] ⏳
    │                       (Fedora)
    │
    └──────────────────────────────────── High Effort
       Low Effort
```

**Legend**:
- ✅ Implemented
- ⏳ Planned
- ❌ Skipped

---

## Release Workflow (v1.0.1 Example)

### 1. Update Version

```bash
# bin/git-issue (or wherever VERSION is defined)
VERSION="1.0.1"
```

### 2. Update Formula SHA256

```bash
# Create tarball
git archive --format=tar.gz --prefix=git-issue-v1.0.1/ v1.0.1 > git-issue-v1.0.1.tar.gz

# Compute SHA256
shasum -a 256 git-issue-v1.0.1.tar.gz
# Output: abc123def456... git-issue-v1.0.1.tar.gz

# Update Formula/git-issue.rb
# sha256 "abc123def456..."
# version "1.0.1"
# url "https://github.com/remenoscodes/git-native-issue/releases/download/v1.0.1/git-issue-v1.0.1.tar.gz"
```

### 3. Create Git Tag

```bash
git tag -s v1.0.1 -m "Release v1.0.1"
git push origin v1.0.1
```

### 4. Create GitHub Release

```bash
gh release create v1.0.1 \
  --title "v1.0.1: Critical spec fixes" \
  --notes-file CHANGELOG.md \
  git-issue-v1.0.1.tar.gz
```

### 5. Test Installation

```bash
# Test Homebrew install
brew uninstall git-issue || true
brew install --build-from-source remenoscodes/git-issue/git-issue
git issue version

# Test install.sh
curl -sSL https://raw.githubusercontent.com/remenoscodes/git-issue/v1.0.1/install.sh | sh
git issue version

# Test make install
git clone https://github.com/remenoscodes/git-native-issue.git
cd git-issue
make install prefix=~/.local
git issue version
```

### 6. Update AUR (if exists)

```bash
# Update PKGBUILD
pkgver=1.0.1
sha256sums=('...')  # From tarball

# Submit to AUR
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO
git commit -m "Update to v1.0.1"
git push
```

---

## Success Metrics

**3 months**:
- ✅ 50+ Homebrew installs/month
- ✅ 20+ AUR votes
- ✅ install.sh tested on 5+ platforms (macOS, Ubuntu, Arch, Debian, Alpine)

**6 months**:
- ✅ 200+ Homebrew installs/month
- ✅ AUR package marked "popular" (10+ votes)
- ✅ At least 1 user submits Nix package to nixpkgs

**12 months**:
- ✅ 500+ installs/month across all methods
- ✅ Debian package requested by users
- ✅ Package available in at least 4 ecosystems (Homebrew, AUR, Nix, asdf)

---

## FAQ

### Q: Why not a separate homebrew-tap repo?

**A**: Unnecessary for a single tool. In-repo formula is simpler (one source of truth, atomic version updates). We can move to a separate tap IF we build multiple tools later.

### Q: Why AUR before .deb/.rpm?

**A**: Arch users are CLI power users (our target audience). AUR is trivial (just a PKGBUILD file). .deb/.rpm require more packaging effort with less targeted reach.

### Q: Why asdf plugin?

**A**: Developers using asdf manage ALL their tools this way (Node, Ruby, Python, etc.). They'll naturally want git-issue available via asdf too. Low effort, targeted audience.

### Q: Why not Snap?

**A**: Snap has poor UX for CLI tools (slow startup, confinement issues). The community consensus is that Snap works better for GUI apps, not CLI tools.

### Q: Should we support Windows?

**A**: Git Bash on Windows works fine with the shell scripts. WSL users can use install.sh or Homebrew (on WSL2). Native Windows installer (MSI/Chocolatey) is low priority unless demand emerges.

---

## Next Steps (This Week)

1. ✅ Create `install.sh` (DONE)
2. ✅ Create `Formula/git-issue.rb` in-repo (DONE)
3. ✅ Update README with installation methods (DONE)
4. ⏳ Test install.sh on clean VM
5. ⏳ Commit Formula/ and install.sh
6. ⏳ Update for v1.0.1 release
7. ⏳ Test Homebrew install: `brew install remenoscodes/git-issue/git-issue`

---

**Last Updated**: 2026-02-08
**Next Review**: After v1.0.1 public launch
