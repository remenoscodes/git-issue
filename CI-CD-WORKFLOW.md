# CI/CD Workflow Documentation

**Last Updated**: 2026-02-08
**Status**: ✅ Automated (with manual Homebrew update step)

---

## 🔄 Overview

git-issue uses GitHub Actions for continuous integration and automated releases.

**Workflows**:
1. **CI** (`.github/workflows/ci.yml`) - Tests on every push/PR
2. **Release** (`.github/workflows/release.yml`) - Creates releases on tag push

---

## ✅ CI Workflow (`ci.yml`)

### Triggers
- Push to `main` branch
- Pull requests to `main` branch

### Runs On
- `ubuntu-latest` (Linux)
- `macos-latest` (macOS)

### Steps
1. Checkout code
2. Install dependencies (jq on Linux)
3. Run all test suites:
   - `t/test-issue.sh` (76 tests - core)
   - `t/test-merge.sh` (20 tests - merge)
   - `t/test-qol.sh` (21 tests - QoL)
   - `t/test-bridge.sh` (36 tests - GitHub bridge)
4. Verify `make install` works

### Success Criteria
- All 153 tests pass on both Ubuntu and macOS
- Installation via Makefile succeeds

### View Results
https://github.com/remenoscodes/git-issue/actions/workflows/ci.yml

---

## 🚀 Release Workflow (`release.yml`)

### Triggers
- Push tag matching `v*` (e.g., `v1.0.1`)

### Permissions
- `contents: write` (to create releases)

### Steps

#### 1. Get Version from Tag
- Extracts version number from tag (e.g., `v1.0.1` → `1.0.1`)
- Sets outputs: `version` (v1.0.1) and `version_number` (1.0.1)

#### 2. Verify Version Matches
- Checks `VERSION` variable in `bin/git-issue`
- **FAILS** if code version ≠ tag version
- Prevents releasing wrong version

#### 3. Create Tarball
Includes:
- `bin/` - All git-issue commands
- `Makefile` - Installation support
- `LICENSE` - GPL-2.0
- `README.md` - User guide
- `ISSUE-FORMAT.md` - Format specification ✨
- `install.sh` - Universal install script
- `doc/` - Man pages (if present)
- `Formula/` - Homebrew formula (for reference)

Outputs:
- Tarball: `git-issue-v1.0.1.tar.gz`
- SHA256 hash (for Homebrew formula)

#### 4. Test Tarball Installation
- Extracts tarball
- Runs `make install prefix=/tmp/test`
- Verifies binaries are executable
- Tests `git issue version` command

**Ensures release artifact actually works!**

#### 5. Generate Changelog
- Lists commits since previous tag
- Adds installation instructions
- Includes SHA256 checksum
- Saved to release notes

#### 6. Create GitHub Release
- Publishes release on GitHub
- Attaches tarball as downloadable asset
- Uses generated changelog as release description

#### 7. Homebrew Formula Update Reminder
- Prints manual update instructions
- Provides exact SHA256 and URL to update
- **NOT automated** (requires manual commit)

---

## 📋 Release Process (Step-by-Step)

### For Maintainers: How to Release v1.0.1

#### Step 1: Update Version in Code
```bash
cd ~/source/remenoscodes.git-issue

# Edit bin/git-issue
# Change: VERSION="1.0.0"
# To:     VERSION="1.0.1"
```

#### Step 2: Commit Version Bump
```bash
git add bin/git-issue
git commit -m "Bump version to 1.0.1"
git push origin main
```

#### Step 3: Create and Push Tag
```bash
git tag -s v1.0.1 -m "Release v1.0.1

Critical spec fixes from council review:
- Newline injection security fix
- Label merge limitations documented
- N-way merge ordering specified
- Conflict representation deferred to v2

Installation improvements:
- In-repo Homebrew formula
- Universal install.sh script
- GitHub bridge bug fixes

All 153 tests passing.
Ready for public launch."

git push origin v1.0.1
```

#### Step 4: GitHub Actions Runs Automatically
Watch progress at: https://github.com/remenoscodes/git-issue/actions

The workflow will:
1. ✅ Verify version matches tag
2. ✅ Create tarball with all files
3. ✅ Test tarball installation
4. ✅ Generate changelog
5. ✅ Create GitHub release
6. ✅ Upload tarball as asset

#### Step 5: Update Homebrew Formula (Manual)

After release completes, GitHub Actions will print:
```
⚠️  MANUAL STEP REQUIRED:
Update Formula/git-issue.rb with:
  version: 1.0.1
  sha256: abc123...
  url: https://github.com/remenoscodes/git-issue/releases/download/v1.0.1/git-issue-v1.0.1.tar.gz
```

Update the formula:
```bash
# Edit Formula/git-issue.rb
# Update these lines:
  version "1.0.1"
  sha256 "abc123def456..."  # From GitHub Actions output
  url "https://github.com/remenoscodes/git-issue/releases/download/v1.0.1/git-issue-v1.0.1.tar.gz"

git add Formula/git-issue.rb
git commit -m "Update Homebrew formula for v1.0.1

- Version: 1.0.1
- SHA256: abc123def456...
- Tarball: git-issue-v1.0.1.tar.gz"

git push origin main
```

#### Step 6: Test Homebrew Installation
```bash
brew uninstall git-issue || true
brew untap remenoscodes/git-issue || true
brew install remenoscodes/git-issue/git-issue
git issue version  # Should show: git-issue version 1.0.1
```

#### Step 7: Announce
- Post to Hacker News
- Cross-post to Reddit
- Tweet about it
- Update documentation

---

## 🤖 Automated vs Manual

### ✅ Fully Automated
- Test suite execution (CI)
- Tarball creation
- SHA256 computation
- GitHub release creation
- Tarball validation
- Changelog generation

### ⚠️ Manual Steps Required
1. **Version bump** - Update `VERSION="1.0.1"` in `bin/git-issue`
2. **Tag creation** - `git tag -s v1.0.1 && git push origin v1.0.1`
3. **Homebrew formula update** - Copy SHA256 from Actions, update `Formula/git-issue.rb`

### Why Not Fully Automated?

**Homebrew formula update could be automated**, but:
- Requires committing to main from Actions (permission risk)
- Manual review ensures correctness
- Only happens ~monthly (low burden)
- Gives opportunity to verify SHA256 manually

**Future**: Consider automating with a bot account + PR workflow.

---

## 🔍 Monitoring & Debugging

### Check CI Status
```bash
gh run list --workflow=ci.yml --limit 5
```

### Check Release Status
```bash
gh run list --workflow=release.yml --limit 5
```

### View Specific Run
```bash
gh run view <run-id>
```

### Download Release Artifacts
```bash
gh release download v1.0.1
```

### Verify Tarball
```bash
tar tzf git-issue-v1.0.1.tar.gz | head -20
shasum -a 256 git-issue-v1.0.1.tar.gz
```

---

## 🐛 Common Issues

### Issue: "Version mismatch" error

**Cause**: `VERSION` in `bin/git-issue` doesn't match git tag

**Fix**:
```bash
# Update bin/git-issue to match tag
# If tag is v1.0.1, VERSION must be "1.0.1"
git add bin/git-issue
git commit --amend --no-edit
git tag -d v1.0.1
git push --delete origin v1.0.1
git tag -s v1.0.1 -m "..."
git push origin v1.0.1
```

### Issue: Tarball installation test fails

**Cause**: Missing files in tarball or broken Makefile

**Debug**:
```bash
# Download tarball from failed release
tar tzf git-issue-v1.0.1.tar.gz
# Check if all expected files present

# Try installing locally
tar xzf git-issue-v1.0.1.tar.gz
cd git-issue-v1.0.1
make install prefix=/tmp/test
```

**Fix**: Update release workflow to include missing files

### Issue: Homebrew formula SHA256 mismatch

**Cause**: Tarball changed after formula update

**Fix**:
```bash
# Re-download tarball
gh release download v1.0.1

# Compute correct SHA256
shasum -a 256 git-issue-v1.0.1.tar.gz

# Update formula with correct hash
```

---

## 📊 Release Metrics

Track these after each release:

**GitHub**:
- Stars: `gh repo view remenoscodes/git-issue --json stargazerCount`
- Forks: `gh repo view remenoscodes/git-issue --json forkCount`
- Downloads: Check release page

**Homebrew**:
- Installs: (need to set up analytics)

**AUR** (when available):
- Votes: https://aur.archlinux.org/packages/git-issue

---

## 🚀 Future Improvements

### Priority 1: Homebrew Auto-Update Bot
- Create GitHub Actions workflow
- Auto-commit formula updates
- Create PR for review

### Priority 2: Multi-Platform Testing
- Add Windows (Git Bash) to CI
- Add FreeBSD to CI

### Priority 3: Release Automation
- Auto-bump version from tag
- One-command release (`make release VERSION=1.0.1`)

### Priority 4: Package Registry
- Publish to GitHub Packages
- Publish to NPM (for npx git-issue)

---

## 📚 References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)

---

**Questions?** File an issue: https://github.com/remenoscodes/git-issue/issues
