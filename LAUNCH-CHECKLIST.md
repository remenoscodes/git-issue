# Launch Checklist - Tuesday 2026-02-11

## ✅ Completed (All 7 Blockers Fixed)

1. ✅ CI workflow updated with new repo names
2. ✅ Shellcheck linting added to CI
3. ✅ CI added to Homebrew tap repo
4. ✅ CI added to asdf plugin repo
5. ✅ GPG signing added to workflow (optional, can enable later)

## 🔄 In Progress (Testing & Validation)

### 1. Test Homebrew Installation (10 min)
```bash
brew uninstall git-native-issue 2>/dev/null || true
brew tap remenoscodes/git-native-issue
brew install git-native-issue
git-issue version
```

### 2. Test asdf Installation (10 min)
```bash
asdf plugin remove git-native-issue 2>/dev/null || true
asdf plugin add git-native-issue https://github.com/remenoscodes/git-native-issue-asdf.git
asdf install git-native-issue 1.0.1
asdf global git-native-issue 1.0.1
git-issue version
```

### 3. Create v1.0.2 Release (30 min)
- [ ] Update VERSION in bin/git-issue to 1.0.2
- [ ] Commit and push
- [ ] Create and push v1.0.2 tag: `git tag -s v1.0.2 -m "Release v1.0.2" && git push origin v1.0.2`
- [ ] Wait for release workflow to complete
- [ ] Verify tarball created: `git-native-issue-v1.0.2.tar.gz`
- [ ] Verify Homebrew formula auto-updated
- [ ] Download and test tarball

### 4. Update PKGBUILD SHA256 (5 min)
- [ ] Download new tarball
- [ ] Compute SHA256: `shasum -a 256 git-native-issue-v1.0.2.tar.gz`
- [ ] Update PKGBUILD pkgver and sha256sums
- [ ] Commit and push

### 5. Final Smoke Tests (15 min)
- [ ] Test Homebrew install (v1.0.2)
- [ ] Test asdf install (v1.0.2)
- [ ] Test direct tarball install
- [ ] Test install.sh script
- [ ] Verify all produce identical binaries

### 6. Documentation Review (15 min)
- [ ] README URLs all correct
- [ ] Launch post final review
- [ ] HN title fits (80 chars max)
- [ ] Reddit formatting tested

## 📋 Launch Day (Tuesday Morning)

### Pre-Launch (30 min before)
- [ ] Final smoke test all installation methods
- [ ] Check GitHub Actions all green
- [ ] Verify latest commit is signed
- [ ] Test HN link formatting

### Launch (9:00 AM PT - optimal time)
- [ ] Post to Hacker News (Show HN)
- [ ] Monitor for first 2 hours (quick responses help)
- [ ] Have answers ready for common questions

### Post-Launch (Same Day)
- [ ] Wait 24 hours, then Reddit (r/programming, r/git)
- [ ] Lobsters if accepted
- [ ] Dev.to/Hashnode blog post

## 🎯 Success Metrics (Week 1)

- GitHub stars: 50+
- Homebrew installs: 20+
- HN front page (top 30)
- Zero critical bugs reported

## 📝 Notes

GPG Signing:
- Workflow supports it but currently disabled
- Can enable post-launch by adding secrets
- Not critical for initial launch

Time to Launch: ~1.5 hours remaining work
Confidence: HIGH ✅
