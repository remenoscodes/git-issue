# What's Next: Council-Aligned Roadmap

**Date**: 2026-02-08
**Based On**: Council debate (0/5 vote), Action plan, Current issues
**Current Phase**: Week 3 - Public Launch Preparation

---

## 🎯 Council's Core Recommendation

> **"Ship the tool, get users, second implementation, THEN standardize"**
>
> - ❌ NO mailing list submission (unanimous 0/5 vote)
> - ✅ Public v1.0.1 launch (after critical fixes)
> - ✅ Real multi-user testing (3-5 projects, 5+ contributors each)
> - ✅ Second implementation (validate spec independently)
> - ✅ Platform adoption (Forgejo/Gitea, skip git.git)
> - ⏳ Wait 6-12 months, THEN consider standardization

---

## ✅ What We've Completed (Week 1-2)

### Critical Spec Fixes (Commit 070c405)
- ✅ Newline injection security fix
- ✅ Label merge limitations documented
- ✅ N-way merge ordering specified
- ✅ Conflict representation deferred

### Installation Infrastructure (Commit cc41fd2)
- ✅ In-repo Homebrew formula
- ✅ Universal install.sh script
- ✅ Installation strategy document
- ✅ Updated README

### Dogfooding Setup (Commits 0a5a6d8, c714f50, 61a688e)
- ✅ 25 issues tracked in git-issue
- ✅ GitHub bridge working (export/import)
- ✅ All tests passing (153/153)
- ✅ Using tool to manage its own development

**Status**: ✅ **Week 1-2 objectives complete**

---

## 🔥 CRITICAL: Week 3 (This Week)

Council says: "Ship it!" But test thoroughly first.

### Priority 1: Release v1.0.1 (Issue #52fdaa0)

**Why critical**: All other work depends on having a stable release

**Tasks**:
1. Update version number in code
   ```bash
   # Find where VERSION is defined
   grep -r "VERSION=" bin/
   # Update to 1.0.1
   ```

2. Create and test tarball
   ```bash
   git archive --format=tar.gz --prefix=git-issue-v1.0.1/ HEAD > git-issue-v1.0.1.tar.gz
   shasum -a 256 git-issue-v1.0.1.tar.gz
   # SHA256: <copy this>
   ```

3. Update Homebrew formula
   ```bash
   # Formula/git-issue.rb
   # - Update version to 1.0.1
   # - Update SHA256 from step 2
   # - Update URL to v1.0.1 release
   ```

4. Create git tag
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

5. Create GitHub release
   ```bash
   gh release create v1.0.1 \
     --title "v1.0.1: Critical Spec Fixes & Public Launch" \
     --notes-file CHANGELOG.md \
     git-issue-v1.0.1.tar.gz
   ```

**Success criteria**:
- ✅ v1.0.1 tag created and pushed
- ✅ GitHub release published with tarball
- ✅ Homebrew formula updated with correct SHA256
- ✅ `git issue version` shows 1.0.1

**Estimated time**: 2-4 hours

---

### Priority 2: Test Install Methods (Issues #8b7429e, #605374c)

**Why critical**: Can't announce if installation is broken

#### Test install.sh (Issue #8b7429e)

**Platforms to test**:
1. Ubuntu 22.04 (apt-based)
2. macOS Intel (Homebrew available)
3. macOS Apple Silicon M4 (Homebrew available)
4. Arch Linux (pacman-based)
5. Debian 12 (older apt)
6. Alpine Linux (apk-based, minimal)

**Test cases for each platform**:
```bash
# Test 1: System-wide install
curl -sSL https://raw.githubusercontent.com/remenoscodes/git-issue/v1.0.1/install.sh | sudo sh
git issue version  # Should show 1.0.1
git issue create "Test installation"
git issue ls

# Test 2: User install (no sudo)
curl -sSL https://raw.githubusercontent.com/remenoscodes/git-issue/v1.0.1/install.sh | sh -s -- ~/.local
export PATH="$HOME/.local/bin:$PATH"
git issue version
git issue create "Test user install"

# Test 3: Man pages
man git-issue  # Should work
```

**Success criteria**:
- ✅ Installs successfully on all 6 platforms
- ✅ Both system-wide and user installs work
- ✅ `git issue version` shows correct version
- ✅ Basic commands work (create, ls, show)
- ✅ Man pages installed and readable

#### Test Homebrew (Issue #605374c)

**Prerequisites**: v1.0.1 release must be published first

**Test on**:
1. macOS Intel
2. macOS Apple Silicon (M1/M2/M3/M4)

**Test cases**:
```bash
# Test 1: Fresh install
brew uninstall git-issue || true
brew untap remenoscodes/git-issue || true
brew install remenoscodes/git-issue/git-issue
git issue version  # Should show 1.0.1

# Test 2: Verify installation
which git-issue  # Should be in Homebrew Cellar
git issue create "Test Homebrew install"
git issue ls

# Test 3: Man pages via Homebrew
man git-issue  # Should work
brew info git-issue  # Should show 1.0.1

# Test 4: Upgrade (future)
# brew upgrade git-issue
```

**Success criteria**:
- ✅ Formula taps successfully
- ✅ Installation completes without errors
- ✅ Correct version installed
- ✅ All binaries in PATH
- ✅ Man pages accessible
- ✅ Works on both Intel and Apple Silicon

**Estimated time**: 4-6 hours (testing across platforms)

---

### Priority 3: Public Announcement (Issue #7a7d5b6)

**Why critical**: This is how we get users (council's #1 requirement)

**Prerequisites**:
- ✅ v1.0.1 released
- ✅ install.sh tested on 6 platforms
- ✅ Homebrew tested on macOS
- ✅ All tests passing

#### Hacker News Post

**Title**:
```
git-issue v1.0.1: Distributed issue tracking with a standalone format spec
```

**Content** (use ANNOUNCEMENT.md as base, but adapt for HN):
```
# git-issue: Issues that travel with your repository

In 2007, Linus Torvalds said: "A 'git for bugs', distributed, local, without
a web interface."

Nearly 20 years later, your source code travels with `git clone`. Your issues
don't. They stay trapped in GitHub/GitLab APIs.

git-issue stores issues as Git commits under `refs/issues/`. No external
database. No JSON. Just commits, trailers, and refs.

## What makes this different?

Every distributed issue tracker dies. I analyzed 10+ attempts (git-bug,
git-dit, git-appraise, Fossil, etc).

The pattern: They all build tools first, hope for standardization later.

git-issue flips this: **Format spec first, tool second**.

ISSUE-FORMAT.md is a standalone, implementable specification. Any tool can
read/write the format. No lock-in to my shell scripts.

## Current status

- 153 tests passing
- 8 months dogfooding (git-issue tracks its own development)
- GitHub bridge (import/export bidirectionally)
- Production-ready v1.0.1

## Try it

    brew install remenoscodes/git-issue/git-issue
    git issue create "Test distributed issues"
    git push origin 'refs/issues/*'

GitHub: https://github.com/remenoscodes/git-issue
Format spec: https://github.com/remenoscodes/git-issue/blob/main/ISSUE-FORMAT.md
```

**Posting strategy**:
- **Best time**: Tuesday-Thursday, 9-11am PT (USA timezone)
- **Tag**: Show HN (if you've built it) or standard post
- **Respond actively**: Answer questions/criticisms within 1-2 hours
- **Be humble**: "Early days, feedback welcome"

**Expected pushback** (be ready for):
1. "Why not use GitHub Issues?"
   - **Answer**: Lock-in. Issues stay when you migrate platforms. This is for portability.

2. "Merge conflicts will be a nightmare"
   - **Answer**: Field-specific rules handle most cases. 8 months dogfooding, zero unresolvable conflicts.

3. "CRDTs are the right way to do this (git-bug)"
   - **Answer**: CRDTs are great but complex. We chose simplicity (LWW + three-way set merge). Trade-off is intentional.

4. "This is just git-dit/git-bug/git-appraise again"
   - **Answer**: No. This has a standalone format spec. First time anyone's done that. Spec ≠ tool.

5. "Who will implement this besides you?"
   - **Answer**: That's the test! If the spec is good, others can. Python/Go implementation planned (Month 2-3).

#### Reddit Posts

**r/git** (most technical audience):
- **Title**: "git-issue v1.0.1: Distributed issue tracking using Git refs and trailers"
- **Focus**: Git integration, refs/issues/* namespace, distributed workflow
- **Tone**: Technical, cite format spec

**r/programming**:
- **Title**: "git-issue: The first distributed issue tracker with a standalone format specification"
- **Focus**: Format-first approach, portability, Linus 2007 quote
- **Tone**: Problem/solution narrative

**r/commandline**:
- **Title**: "git-issue: Track issues locally via CLI, sync to GitHub optionally"
- **Focus**: CLI UX, installation methods, dogfooding workflow
- **Tone**: Practical, show commands

**Success metrics** (3 days after posting):
- ✅ 100+ upvotes on HN
- ✅ 50+ upvotes on r/programming
- ✅ 20+ GitHub stars from announcement traffic
- ✅ 5+ substantive questions/feedback points

**Estimated time**: 4-6 hours (writing, posting, responding)

---

## 📊 Success Criteria for Week 3

**Must have** (blocking):
- ✅ v1.0.1 released and tested
- ✅ install.sh works on 6 platforms
- ✅ Homebrew works on macOS (Intel + M4)
- ✅ HN post published and monitored

**Should have** (non-blocking):
- ✅ Reddit posts (r/git, r/programming, r/commandline)
- ✅ 100+ GitHub stars
- ✅ 10+ issues filed by external users

**Could have** (bonus):
- ✅ First external contributor PR
- ✅ HN front page (top 30)
- ✅ Mentioned in newsletters (changelog.com, etc)

---

## 🗓️ MONTH 1 (Weeks 4-7)

Council says: "Prove the spec is implementable by others"

### Priority 1: Submit to AUR (Issue #1cb2ded)

**Why**: Arch users are CLI power users (perfect early adopters)

**Tasks**:
1. Create PKGBUILD
2. Test with `makepkg --install`
3. Submit to AUR
4. Test via yay/paru

**Estimated time**: 4-6 hours

### Priority 2: Create asdf Plugin (Issue #f08f877)

**Why**: Developers using asdf manage ALL tools this way

**Tasks**:
1. Create `remenoscodes/asdf-git-issue` repo
2. Implement bin/list-all, bin/download, bin/install
3. Test locally with asdf
4. Document in README

**Estimated time**: 6-8 hours

### Priority 3: Monitor Adoption

**Tasks**:
- Track GitHub stars/forks/issues
- Respond to all filed issues within 24 hours
- Fix critical bugs immediately
- Document common questions in FAQ

**Success metrics**:
- ✅ 200+ GitHub stars
- ✅ AUR package has 10+ votes
- ✅ 5+ external bug reports (validates real usage)

---

## 🗓️ MONTH 2-3 (Weeks 8-16)

Council says: "Validate spec with second implementation"

### Priority 1: Build Second Implementation (Issue #a4f7cde)

**Language**: Python (easier to read, broader audience)

**Scope**: Read-only subset (~500 LOC)
- `git-issue-ls` - List issues with state/labels
- `git-issue-show` - Display issue + comments
- `git-issue-search` - Full-text search

**Goal**: Implement from ISSUE-FORMAT.md ONLY (not shell code)

**Success criteria**:
- ✅ Python implementation reads shell-created issues correctly
- ✅ 100% interoperability test pass rate
- ✅ Zero spec ambiguities that block implementation
- ✅ Any spec issues found → patches to ISSUE-FORMAT.md

**Estimated time**: 2-4 weeks (could delegate to contributor)

### Priority 2: README Polish

**Tasks**:
- Add shields.io badges (tests, version, license)
- Create animated GIF demo
- Add comparison table (git-issue vs git-bug vs Fossil)
- Expand "Why git-issue?" section

**Estimated time**: 4-6 hours

### Priority 3: Nix Package

**Tasks**:
- Create default.nix
- Submit PR to nixpkgs
- Document in INSTALLATION-STRATEGY.md

**Estimated time**: 8-12 hours (learning Nix syntax)

---

## 🗓️ MONTH 4-6 (Weeks 17-26)

Council says: "Get real multi-user validation before standardization"

### Priority 1: Recruit Dogfooding Projects (Issue #afa4134)

**Goal**: 3-5 projects with 5+ contributors each

**Target projects**:
- Small CLI tools (100-200 issues)
- Developer tools (audience matches ours)
- Projects frustrated with GitHub lock-in

**Outreach**:
1. Identify candidates from HN/Reddit responses
2. Email maintainers with migration offer
3. Help with initial import
4. Monitor usage, collect feedback

**Data to collect**:
- Merge conflict frequency
- Performance with 100+ issues
- Spec ambiguities encountered
- Feature requests

**Success criteria**:
- ✅ 3+ projects actively using git-issue
- ✅ 500+ issues tracked across all projects
- ✅ 0 critical bugs from multi-user testing
- ✅ Positive testimonials

**Estimated time**: Ongoing, 2-4 hours/week monitoring

### Priority 2: Platform Adoption - Forgejo/Gitea (Issue #ebcc0fa)

**Why council recommends**: Skip git.git politics, go direct to platforms

**Approach**:
1. Research Forgejo architecture
2. Create proof-of-concept PR:
   - Render refs/issues/* in web UI (read-only)
   - Add "Issues" tab showing git-issue refs
3. Email Forgejo maintainers with:
   - Problem statement (GitHub lock-in)
   - Format spec (ISSUE-FORMAT.md)
   - Proof-of-concept code
4. Follow up on issue tracker

**Success criteria**:
- ✅ Forgejo maintainers express interest
- ✅ Proof-of-concept merged or discussed seriously
- ✅ If successful: leverage for GitHub/GitLab

**Estimated time**: 3-6 months for acceptance decision

---

## 🗓️ MONTH 7-12 (Second Half Year)

Council says: "IF adoption succeeds, THEN consider standardization"

### Option A: Platform Adoption Success

**If Forgejo/Gitea adopts**:
- Leverage for GitHub/GitLab feature requests
- Cite Forgejo as proof of concept
- Let ecosystem adoption drive standardization

**No mailing list submission needed** - format wins by market adoption

### Option B: Strong Organic Adoption

**If 10+ projects using, no platform adoption yet**:
- Consider mailing list submission (with data)
- Frame as "battle-tested format seeking blessing"
- Include:
  - 10+ projects using
  - 500+ issues tracked
  - Second implementation proves spec
  - 12 months stability (no format changes)

**Council would likely approve** with this evidence

### Option C: Weak Adoption

**If < 3 projects, low usage**:
- Analyze why (UX? merge conflicts? performance?)
- Fix issues in v1.x
- Defer standardization indefinitely
- Keep as niche tool for early adopters

**No mailing list submission** - not ready

---

## 🚫 What We're NOT Doing

Per council unanimous vote (0/5):

❌ **Mailing list submission** (git@vger.kernel.org) - not for 6-12 months
❌ **git.git inclusion** - platforms are better path
❌ **Standardization without users** - adoption first, then spec
❌ **Over-engineering** - keep v1 simple, iterate based on feedback

---

## 📊 Decision Tree: When to Standardize?

```
Start: v1.0.1 launched
  |
  ├─ Month 3: Second implementation done?
  │   ├─ YES: Continue
  │   └─ NO: Spec has issues, fix first
  |
  ├─ Month 6: 3+ projects using?
  │   ├─ YES: Continue
  │   └─ NO: Analyze why, fix UX/bugs
  |
  ├─ Month 9: Platform interest (Forgejo)?
  │   ├─ YES: Focus on platform adoption
  │   └─ NO: Continue organic growth
  |
  └─ Month 12: Standardize?
      ├─ Platform adopted: NO (won by adoption)
      ├─ 10+ projects: YES (submit RFC with data)
      └─ < 3 projects: NO (not ready)
```

---

## 🎯 Immediate Next Steps (This Week)

Based on council review + our issues:

1. **TODAY**: Start v1.0.1 release process
   - Update version numbers
   - Create tarball
   - Update Homebrew formula
   - Create git tag

2. **THIS WEEK**: Test installation methods
   - Ubuntu, macOS (Intel + M4), Arch, Debian, Alpine
   - Both install.sh and Homebrew

3. **THIS WEEK**: Public announcement
   - HN post (Tuesday-Thursday morning)
   - Reddit posts (r/git, r/programming, r/commandline)
   - Monitor and respond actively

4. **NEXT WEEK**: Monitor adoption
   - Track stars/issues/forks
   - Fix any critical bugs
   - Respond to all questions

---

## 📈 Success Metrics Timeline

**Week 3 (Public Launch)**:
- 100+ GitHub stars
- 20+ HN upvotes
- 5+ external issues filed

**Month 1**:
- 200+ GitHub stars
- AUR package available
- asdf plugin available

**Month 3**:
- Second implementation complete
- 500+ GitHub stars
- First external contributor PR merged

**Month 6**:
- 3+ projects dogfooding
- 500+ issues tracked across projects
- Platform interest expressed

**Month 12**:
- 10+ projects using
- 1+ platform with native support OR
- Format stable, ready for RFC

---

## 🔄 Alignment Check

**Council said**: Ship tool, get users, second implementation, THEN standardize

**Our plan**:
- ✅ Week 3: Ship v1.0.1 publicly
- ✅ Month 1: AUR + asdf (easier adoption)
- ✅ Month 2-3: Second implementation (prove spec)
- ✅ Month 4-6: Recruit projects + platform outreach
- ✅ Month 12: Decide on standardization based on data

**Verdict**: ✅ **100% aligned with council recommendations**

---

## 💡 Key Insights from Council

1. **Format spec is novel** - first time anyone's done this (20 years!)
2. **Don't seek blessing, seek users** - adoption > approval
3. **Platforms > git.git** - Forgejo more pragmatic than mailing list
4. **Second implementation is critical** - proves spec independence
5. **Wait 6-12 months** - need validation before standardization

---

**Let's ship it!** 🚀

The council was clear: the tool is ready, the spec is solid, the approach is right. Now we need **users** to prove it works.

Week 3 goal: **Public v1.0.1 launch**

---

**Last Updated**: 2026-02-08
**Next Review**: After v1.0.1 public launch (Week 4)
