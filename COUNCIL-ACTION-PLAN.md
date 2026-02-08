# Council Review Action Plan - Execution Status

**Created**: 2026-02-08
**Council Review**: Documentation/reviews/council-debate-v1.0.0.md
**Council Vote**: 0/5 to submit to mailing list now (unanimous rejection)
**Recommendation**: Ship tool, get users, second implementation, THEN standardize

---

## IMMEDIATE FIXES (Week 1-2) ✅ COMPLETED

### Commit 070c405: "Address critical spec issues from council review"

#### 1. Newline Injection in Trailers ✅ FIXED

**Problem**: Trailer values could contain newlines, enabling injection attacks
**Council Finding**: Linus + Junio flagged as CRITICAL security issue

**Spec Fixes**:
- ✅ Added Section 4.9 "Trailer Value Encoding"
- ✅ Documented MUST NOT contain newlines requirement
- ✅ Provided POSIX shell validation example
- ✅ Updated ABNF grammar notes to reference Section 4.9

**Code Fixes**:
- ✅ `bin/git-issue-state`: Added validation for `--fixed-by`, `--release`, `--reason`
- ✅ `bin/git-issue-create`: Already protected (uses `validate_no_newlines` from git-issue-lib)
- ✅ `bin/git-issue-edit`: Already protected (uses `validate_no_newlines` for all trailers)

**Test Status**: All 153 tests pass (no regressions)

---

#### 2. Label Semantic Conflicts ✅ DOCUMENTED

**Problem**: Three-way set merge doesn't detect `bug`/`Bug` or `enhancement`/`feature` collisions
**Council Finding**: Michael Mure flagged as CRITICAL data model limitation

**Spec Fixes**:
- ✅ Added Section 6.3.1 "Label Merge Limitations"
- ✅ Documented 4 classes of conflicts:
  - Case variants (`bug` ≠ `Bug`)
  - Semantic duplicates (`enhancement` ≠ `feature`)
  - Alias collisions (rename + concurrent add)
  - No conflict detection (always produces result)
- ✅ Provided project recommendations (naming conventions, lowercase, lint)
- ✅ Updated Section 12 to list "Advanced label merging" as future extension

**Decision**: NOT fixing in v1.0 (would require semantic analysis or NLP). Documented as limitation with workarounds.

---

#### 3. N-way Merge Ordering ✅ SPECIFIED

**Problem**: Spec only defined 2-way merge; octopus merges (3+ parents) were undefined
**Council Finding**: Junio Hamano flagged as HIGH-severity spec gap

**Spec Fixes**:
- ✅ Added Section 6.9 "N-way Merge (3+ Parents)"
- ✅ Specified pairwise reduction algorithm
- ✅ Documented order dependency (not commutative)
- ✅ Mandated chronological sorting of parents for consistency
- ✅ Provided 3-way merge example (Alice/Bob/Carol scenario)

**Code Status**: `bin/git-issue-merge` currently only handles 2-way merges. N-way merge implementation deferred to v1.1 (low priority - octopus merges rare in practice).

---

#### 4. Conflict Representation ✅ DEFERRED

**Problem**: Section 6.8 described `Conflict:` trailer mechanism but it's not implemented
**Council Finding**: Diomidis Spinellis noted spec-implementation mismatch

**Spec Fixes**:
- ✅ Updated Section 6.8 to note "Deferred to Future Version"
- ✅ Added "Status" paragraph explaining v1.0.0 behavior
- ✅ Justified by 8+ months dogfooding with zero unresolvable conflicts
- ✅ Moved to Section 12 "Future Extensions" as Format-Version 2+ feature

**Rationale**: All conflicts resolved automatically by field-specific heuristics. No observed need in production use.

---

## TESTING ✅ ALL PASS

```
t/test-issue.sh:   76/76 tests passed
t/test-bridge.sh:  36/36 tests passed
t/test-merge.sh:   20/20 tests passed
t/test-qol.sh:     21/21 tests passed
─────────────────────────────────────
Total:            153/153 tests passed ✅
```

No regressions from spec changes.

---

## GIT STATUS ✅ COMMITTED & PUSHED

- **Commit**: 070c405 "Address critical spec issues from council review"
- **Files Changed**:
  - `ISSUE-FORMAT.md` (+196 lines)
  - `bin/git-issue-state` (+31 lines for trailer validation)
- **Branch**: main
- **Remote**: https://github.com/remenoscodes/git-issue.git
- **Status**: Pushed to origin/main ✅

---

## NEAR-TERM ACTIONS (Month 1-3) 🔄 IN PROGRESS

### 1. Public v1.0.1 Launch

**Status**: Ready for launch after critical fixes

- ✅ ANNOUNCEMENT.md written (550 words)
- ✅ Critical spec issues fixed
- ✅ All tests passing
- ⏳ **TODO**: Update version to v1.0.1 in bin/git-issue-version
- ⏳ **TODO**: Create v1.0.1 git tag
- ⏳ **TODO**: Create GitHub release with updated tarball
- ⏳ **TODO**: Post to Hacker News
  - Title: "git-issue v1.0.1: Distributed issue tracking with a standalone format spec"
  - Highlight: First distributed issue tracker with format spec independent of tool
  - Frame: Tool launch, not standardization request
- ⏳ **TODO**: Cross-post to r/git, r/programming, r/commandline

### 2. Homebrew Tap Publication

**Status**: Formula ready, needs testing

- ✅ Formula created at `~/source/remenoscodes.homebrew-tap/Formula/git-issue.rb`
- ⏳ **TODO**: Update formula SHA256 for v1.0.1 tarball
- ⏳ **TODO**: Push homebrew-tap repo to GitHub
- ⏳ **TODO**: Test installation: `brew install remenoscodes/tap/git-issue`
- ⏳ **TODO**: Add installation instructions to README.md

### 3. README Polish

**Status**: Needs updating for v1.0.1

- ⏳ **TODO**: Add shields.io badges (tests, version, license)
- ⏳ **TODO**: Create animated GIF demo (create → comment → merge workflow)
- ⏳ **TODO**: Highlight format spec in opening paragraph
- ⏳ **TODO**: Add comparison table vs git-bug/Fossil/git-appraise
- ⏳ **TODO**: Add "Why git-issue?" section citing Linus 2007 quote

### 4. Second Implementation (Validation)

**Status**: Not started

**Goal**: Prove spec is implementable without reference to shell code

- ⏳ **TODO**: Choose language (Python or Go - council recommended both)
- ⏳ **TODO**: Implement read-only subset (~500 LOC):
  - `git-issue-ls` (list issues with state/labels)
  - `git-issue-show` (display issue + comments)
  - `git-issue-search` (full-text search)
- ⏳ **TODO**: Interoperability test:
  - Create 10 issues with shell implementation
  - Read same issues with Python/Go implementation
  - Verify title, state, labels, comments match
- ⏳ **TODO**: Document any spec ambiguities found

**Timeline**: 2-4 weeks (could delegate to interested contributor)

---

## LONG-TERM STRATEGY (Month 4-12) 📋 PLANNED

### 5. Multi-User Testing (Council's Main Requirement)

**Status**: Not started

**Goal**: Validate format with real multi-contributor projects

- ⏳ **TODO**: Recruit 3-5 open-source projects
  - Criteria: 5+ active contributors, willing to dogfood
  - Target: Projects with 100+ issues (currently only 16 in dogfooding)
- ⏳ **TODO**: Migration support
  - Offer direct help with GitHub → git-issue migration
  - Provide documentation for common workflows
- ⏳ **TODO**: Data collection
  - Track merge conflict frequency
  - Track conflict resolution success rate
  - Measure performance degradation (1000+ issues, 1000+ comments)
  - Document spec ambiguities encountered
- ⏳ **TODO**: Publish case studies

**Success Metrics**:
- 500+ issues tracked across all users
- 0 critical bugs from multi-user testing
- Spec stable (no format changes in 6 months)

### 6. Platform Adoption (Alternative to git.git)

**Status**: Not started

**Council Recommendation**: Skip git.git, go direct to Forgejo/Gitea

#### 6.1 Forgejo/Gitea Approach

- ⏳ **TODO**: Contact Forgejo maintainers directly
- ⏳ **TODO**: Pitch: Native `refs/issues/*` support in web UI
  - Display issues from refs alongside code
  - Create/edit issues via web that write to refs
  - Push/pull issues with standard git fetch/push
- ⏳ **TODO**: Create proof-of-concept PR for Gitea
  - Render `refs/issues/*` in web UI (read-only)
  - Add "Issues" tab showing git-issue refs
- ⏳ **TODO**: Decision point: If Forgejo says no, pivot to GitLab/GitHub

**Timeline**: 3-6 months for acceptance decision

#### 6.2 GitHub/GitLab (If Forgejo succeeds)

- ⏳ **TODO**: Open feature requests citing proven adoption
- ⏳ **TODO**: Frame: "Support displaying refs/issues/* in web UI"
- ⏳ **TODO**: Evidence: Point to Forgejo implementation + user testimonials

---

## DECISION POINTS

### A. Mailing List Submission: YES or NO?

**Council Recommendation**: Skip git.git entirely OR wait 12+ months

**Current Decision**: ❌ **SKIP git.git**

**Rationale**:
- Platform adoption (Forgejo) carries more weight than git.git blessing
- If GitHub/GitLab/Forgejo add native support, format wins by market adoption
- Avoids git.git politics and conservatism
- Faster path to ecosystem validation

**Alternative Path**: IF real-world adoption succeeds (10+ projects, 1+ platform), THEN submit RFC to git@vger.kernel.org backed by adoption data (12+ months from now).

### B. Fix Critical Issues Before Public Launch?

**Decision**: ✅ **FIX FIRST** (COMPLETED)

**Rationale**:
- Critical fixes were spec clarifications, not code rewrites (1-2 weeks)
- Better to document limitations upfront than appear careless
- Newline injection was security-critical (couldn't ship with known vuln)
- Council split, but Junio + Emily preferred fixing first

**Result**: v1.0.1 ready for public launch with all critical issues addressed.

---

## NEXT IMMEDIATE STEPS (Week 3)

1. ✅ ~~Address critical spec issues~~ (DONE - commit 070c405)
2. ⏳ Update version to v1.0.1 in code
3. ⏳ Create v1.0.1 git tag and GitHub release
4. ⏳ Update Homebrew formula SHA256
5. ⏳ Post announcement to HN/Reddit
6. ⏳ Begin recruitment for dogfooding projects

---

## SUCCESS METRICS TRACKER

| Milestone | Target | Current Status |
|-----------|--------|----------------|
| Critical spec fixes | 4/4 | ✅ 4/4 (100%) |
| Test suite passing | 153/153 | ✅ 153/153 (100%) |
| v1.0.1 release | Tagged | ⏳ Not yet tagged |
| Homebrew tap | Published | ⏳ Formula ready, not pushed |
| HN announcement | Posted | ⏳ Not posted |
| Second implementation | Complete | ⏳ Not started (0%) |
| Dogfooding projects | 3-5 projects | ⏳ 0 recruited |
| Platform interest | 1 platform | ⏳ 0 contacted |
| Issues tracked (all users) | 500+ | 16 (self-dogfooding only) |
| Spec stability | 6 months no changes | ⏳ Just updated (Day 0) |

---

## COUNCIL RECOMMENDATIONS COMPLIANCE

| Recommendation | Status | Notes |
|----------------|--------|-------|
| Fix critical spec issues before launch | ✅ Done | Commit 070c405 |
| Ship tool publicly first | ⏳ In progress | v1.0.1 ready |
| Get real users (3-5 projects) | ⏳ Planned | Month 4-6 |
| Build second implementation | ⏳ Planned | Month 2-3 |
| Validate with 100+ issues | ⏳ Planned | Currently 16 |
| Wait 6-12 months before standardization | ✅ Committed | No mailing list submission |
| Approach platforms directly (skip git.git) | ✅ Planned | Forgejo first (Month 4-6) |
| Rewrite mailing list email (if ever used) | ⏳ Deferred | Council's 42-line draft saved |

**Alignment**: 100% aligned with council recommendations. No immediate mailing list submission. Focus on adoption first.

---

## RISKS & MITIGATION

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Spec changes needed after public use | High | 6-month stability window before declaring stable |
| Second implementation finds ambiguities | Medium | Fix in v1.1, document breaking changes |
| No projects want to dogfood | High | Offer migration help, start with small projects |
| Forgejo/Gitea reject proposal | Medium | Pivot to GitHub/GitLab, or build standalone web UI |
| Label merge limitations cause real issues | Medium | Documented workarounds, lint command in v1.1 |

---

## FILES MODIFIED (This Session)

1. **ISSUE-FORMAT.md** (+196 lines)
   - Section 4.9: Trailer Value Encoding (newline injection)
   - Section 6.3.1: Label Merge Limitations
   - Section 6.8: Conflict Representation (deferred)
   - Section 6.9: N-way Merge (3+ Parents)
   - Section 12: Updated Future Extensions

2. **bin/git-issue-state** (+31 lines)
   - Added newline validation for `--fixed-by`, `--release`, `--reason`

3. **COUNCIL-ACTION-PLAN.md** (this file)
   - Comprehensive execution tracker for council recommendations

---

## CONCLUSION

**Week 1-2 Status**: ✅ **CRITICAL FIXES COMPLETE**

All 4 critical spec issues identified by the expert council have been addressed:
- Newline injection: FIXED (spec + code)
- Label semantic conflicts: DOCUMENTED with workarounds
- N-way merge ordering: SPECIFIED with algorithm
- Conflict representation: DEFERRED with justification

The format is now ready for public v1.0.1 release. Next steps focus on launch (HN/Reddit), second implementation validation, and real-world dogfooding.

**No mailing list submission** until 6-12 months of proven adoption, per unanimous council recommendation.

---

**Last Updated**: 2026-02-08 (Commit 070c405)
**Next Review**: After v1.0.1 public launch (Week 3)
