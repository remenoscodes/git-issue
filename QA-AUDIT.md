# Quality Audit - Pre-Launch Checklist

**Date**: 2026-02-08  
**Version**: 1.0.1  
**Status**: Pre-HN Launch

---

## 1. Shell Script Quality ⚠️

### Current State
- **No shellcheck in CI** - Scripts pass basic syntax but not linted
- **Minor issues found**:
  - SC2034: Unused variables (git_dir, errors, checked)
  - SC2295: Expansion quoting in export script
  - SC1091: Info about sourced files (ignorable)

### Action Items
- [ ] Add shellcheck to CI workflow
- [ ] Fix unused variable warnings
- [ ] Add shfmt for consistent formatting
- [ ] Consider adding shell script complexity metrics

### Severity: Medium
Scripts work but could be more robust.

---

## 2. CI/CD Pipeline Validation ✅ / ⚠️

### What's Working
✅ **Main repo tests (test-install.yml)**:
- Tests install.sh on 6 Linux distributions
- Tests Makefile installation
- Tests macOS installation
- Tests Homebrew formula (but references old name)
- Tests asdf plugin (but references old name)
- Tests PKGBUILD build

✅ **End-to-end validation**:
- Verifies binaries installed
- Verifies executability
- Tests version command
- Tests basic init command

### What's Missing ⚠️
❌ **Test references old names**:
- `Formula/git-issue.rb` should be `git-native-issue.rb`
- `brew install remenoscodes/git-issue/git-issue` should be updated
- asdf plugin URL references old repo

❌ **No CI in package repos**:
- `git-native-issue-brew` has no .github/workflows/
- `git-native-issue-asdf` has no .github/workflows/

❌ **No cross-validation**:
- Brew repo doesn't test formula installation
- asdf repo doesn't test plugin functionality
- No integration tests between repos

### Action Items
- [ ] Update test-install.yml with new repo names
- [ ] Add CI to homebrew tap repo
- [ ] Add CI to asdf plugin repo
- [ ] Add formula validation workflow
- [ ] Add plugin validation workflow

### Severity: High (tests reference wrong names)

---

## 3. Release Signing ⚠️

### Current State
✅ **Commits are GPG-signed** (all 94 commits verified)  
✅ **Tags are GPG-signed** (v1.0.0, v1.0.1)  
✅ **SHA256 checksums computed** for release tarballs  
❌ **Release artifacts NOT GPG-signed**

### What's Missing
- Release tarballs have SHA256 but no .asc signature file
- No verification instructions in release notes
- Users can't cryptographically verify downloaded tarballs

### Action Items
- [ ] Add GPG signing of release tarballs to workflow
- [ ] Generate .asc signature files
- [ ] Add verification instructions to release notes
- [ ] Document public key for verification

### Severity: Medium (SHA256 provides integrity, GPG adds authenticity)

---

## 4. Package Manager Validation ⚠️

### Homebrew
✅ Formula syntax valid (Ruby -c passes)  
⚠️ Formula references old repo names  
❌ No automated testing in tap repo  
❌ No version consistency checks

### asdf
✅ Plugin structure correct  
⚠️ Plugin references old repo names  
❌ No automated testing in plugin repo  
❌ No version listing validation

### AUR
✅ PKGBUILD syntax valid  
✅ Package builds successfully  
❌ Not yet submitted to AUR  
⚠️ SHA256 will be wrong after rename (tarball name changed)

### Action Items
- [ ] Update test workflow with new names
- [ ] Fix PKGBUILD SHA256 for new tarball name
- [ ] Add CI to homebrew tap
- [ ] Add CI to asdf plugin
- [ ] Validate version consistency across packages

### Severity: High (tests broken, SHA256 mismatch)

---

## 5. Design Metrics 📊

### Test Coverage
- ✅ 153 tests passing (76 core + 36 bridge + 20 merge/fsck + 21 QoL)
- ✅ Multi-platform tested (6 Linux + macOS)
- ❌ No coverage metrics reported
- ❌ No performance benchmarks

### Code Quality
- Lines of shell: ~3,000 (estimated)
- Cyclomatic complexity: Unknown
- Error handling: Present but not measured
- Documentation: Good (README, man pages, ISSUE-FORMAT.md)

### Suggested Metrics
- [ ] Shell script line coverage (using kcov or bashcov)
- [ ] Performance benchmarks (issues/sec for create, ls, search)
- [ ] Memory usage profiling
- [ ] Cyclomatic complexity (using shellcheck --severity)
- [ ] Error path coverage

### Severity: Low (nice to have, not blocking)

---

## 6. Documentation Quality ✅

### What's Good
✅ Comprehensive README with examples  
✅ ISSUE-FORMAT.md spec (standalone)  
✅ Man pages for all commands  
✅ PACKAGING-SUMMARY.md (distribution guide)  
✅ Installation guides for all methods  

### Minor Gaps
⚠️ No SECURITY.md (vulnerability reporting)  
⚠️ No CODE_OF_CONDUCT.md  
⚠️ No CONTRIBUTING.md (mentioned but not created)

### Severity: Low (can add post-launch)

---

## Critical Pre-Launch Blockers 🚨

### Must Fix Before HN Launch

1. **Update CI test workflow** - Fix repo name references
   - Status: ❌ Broken
   - Impact: CI fails, looks unprofessional
   - Effort: 15 minutes

2. **Fix PKGBUILD SHA256** - Tarball name changed
   - Status: ❌ Broken
   - Impact: AUR package won't build
   - Effort: 5 minutes (need to create release first)

3. **Verify Homebrew formula** - Test with new name
   - Status: ⚠️ Untested
   - Impact: brew install might fail
   - Effort: 10 minutes

4. **Verify asdf plugin** - Test with new name
   - Status: ⚠️ Untested
   - Impact: asdf install might fail
   - Effort: 10 minutes

### Recommended (High Priority)

5. **Add CI to package repos** - Automated validation
   - Status: ❌ Missing
   - Impact: No confidence in package quality
   - Effort: 1 hour

6. **Add shellcheck to CI** - Prevent regressions
   - Status: ❌ Missing
   - Impact: Quality drift over time
   - Effort: 30 minutes

7. **GPG sign releases** - Artifact authenticity
   - Status: ⚠️ Partial (commits signed, tarballs not)
   - Impact: Can't cryptographically verify downloads
   - Effort: 45 minutes

### Nice to Have (Post-Launch)

8. Add test coverage metrics
9. Add performance benchmarks
10. Add SECURITY.md / CODE_OF_CONDUCT.md
11. Shell script complexity analysis

---

## Summary

**Overall Grade**: B+ (Good foundation, needs polish)

**Strengths**:
- Comprehensive test suite (153 tests)
- Multi-platform validation
- Good documentation
- Working package distribution

**Weaknesses**:
- CI references old repo names (CRITICAL)
- No CI in package repos
- Release artifacts not GPG-signed
- No shellcheck in CI

**Recommendation**: Fix critical blockers (1-4) before HN launch. Add items 5-7 in the week after launch.

**Time to launch-ready**: ~1-2 hours (fixing critical issues)

---

**Next Steps**: See action items below.
