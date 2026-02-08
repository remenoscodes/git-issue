# ISSUE-FORMAT.md Spec Polish Summary

**Date**: 2026-02-08
**Task**: Polish format spec for Git mailing list submission
**Status**: Completed

## Changes Made

### 1. Added Non-Goals Section (Section 2)

Added explicit "Non-Goals" section documenting what the format intentionally does NOT address:
- Access control (enforced at repository level, not format level)
- Real-time synchronization (uses git push/fetch)
- Non-developer participation (requires CLI proficiency)
- Binary attachments in v1 (deferred to future version)
- Platform integration requirements (optional)
- Guaranteed conflict-free resolution (uses heuristics, not CRDTs)

This addresses the council review feedback from Emily Shaffer about acknowledging limitations upfront.

### 2. Added Formal ABNF Grammar (Section 4.8)

Added Augmented Backus-Naur Form grammar for commit message format:
- Defines root-commit, comment-commit, state-commit, merge-commit
- Specifies trailer format formally
- Documents UTF-8 support
- Notes that Git uses LF not CRLF
- Provides machine-readable format specification

This helps with formal verification and alternative implementations.

### 3. Section Renumbering

- Old Section 4.8 (Cross-References) → New Section 4.9
- All subsequent sections renumbered automatically
- Internal references remain consistent

### 4. Created Mailing List Draft

Created `/Users/emersonsoares/source/remenoscodes.git-issue/mailing-list-draft.txt` with:

**Subject**: [RFC] Distributed Issue Tracking Format using Git Refs and Trailers

**Key sections**:
- Background (Linus 2007 quote, why existing tools failed)
- The Proposal (format overview, design principles)
- Production Use (1 year v0.1→v1.0.0, 11 commands, 106 tests, dogfooding)
- Request for Format Blessing (NOT tool inclusion)
- Relationship to Existing Git Formats (reftable, protocol v2, Git 2.17+)
- Comparison to Prior Art (git-bug, git-dit, git-appraise, Fossil)
- Non-Goals (explicit limitations)
- Questions for the Community (5 specific questions)
- Next Steps (AsciiDoc conversion, platform adoption, contrib/ patch)

**Tone**: Respectful, technical, focused on format not tool, acknowledges prior art, requests feedback not approval.

**Length**: ~150 lines cover letter + full spec inline (per mailing list conventions)

## AsciiDoc Conversion Decision

Based on council review (Junio Hamano's feedback):
- Git documentation uses AsciiDoc format for man pages
- For initial RFC submission: **Markdown is acceptable**
- For eventual gitformat-issue(5) inclusion: **AsciiDoc required**

**Recommendation**: Submit RFC with Markdown spec first, convert to AsciiDoc only if there's positive reception and interest in formal inclusion.

## Format Validation

The spec now includes:
- RFC 2119 compliance (MUST/SHOULD/MAY) ✓
- RFC 4122 reference (UUID) ✓
- Git 2.17+ minimum version ✓
- Security considerations ✓
- Compatibility notes ✓
- Non-goals section ✓
- Formal grammar (ABNF) ✓

## Next Steps for Team Lead

1. **Review mailing-list-draft.txt** - verify tone and technical accuracy
2. **Test format locally** - ensure ABNF grammar matches implementation
3. **Decision point**: Submit now or wait for more dogfooding?
4. **Mailing list submission process**:
   - Subscribe to git@vger.kernel.org (if not already)
   - Send plain-text email (no HTML)
   - Include full spec inline after cover letter
   - Expect 1-2 week response time
   - Be prepared for multiple rounds of feedback

## Files Modified

- `/Users/emersonsoares/source/remenoscodes.git-issue/ISSUE-FORMAT.md` (added Non-Goals, ABNF grammar, renumbered sections)
- `/Users/emersonsoares/source/remenoscodes.git-issue/mailing-list-draft.txt` (created)
- `/Users/emersonsoares/source/remenoscodes.git-issue/SPEC-POLISH-SUMMARY.md` (this file)

## Council Review Alignment

This polish addresses feedback from:
- **Junio C Hamano**: Added RFC 2119 reference context, minimum Git version clear
- **Emily Shaffer**: Added Non-Goals section, separated format from tool concerns
- **Linus Torvalds**: Kept spec focused on format primitives, no over-engineering
- **Michael Mure**: Acknowledged CRDT trade-offs in Non-Goals
- **D. Richard Hipp**: Clear scope boundaries

Ready for mailing list submission pending team lead approval.
