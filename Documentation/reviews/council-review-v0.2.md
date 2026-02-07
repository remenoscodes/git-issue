# Council of Specialists Review: git-issue v0.2.0

**Date**: 2026-02-07
**Subject**: Review of git-issue standalone implementation v0.2.0
**Repository**: remenoscodes/git-issue
**Artifact versions**: 11 commands, 609-line ISSUE-FORMAT.md, 106 tests (71 core + 35 bridge)

---

## 1. Executive Summary

Seven specialists with deep expertise in Git internals, distributed version control, issue tracking, and open-source governance reviewed the git-issue v0.2.0 implementation. This is the first standalone release of a distributed issue tracker that stores issues as Git commit chains under `refs/issues/`, accompanied by a formal format specification (ISSUE-FORMAT.md).

The council's overall assessment is **cautiously positive**. The implementation faithfully executes the v2 architecture decisions established by the previous council. The format spec is the strongest element -- clear, minimal, and genuinely novel in a space littered with dead tools. The shell implementation is adequate for validation and early adoption but will not scale. The GitHub bridge works but deviates from the spec's own bridge protocol (Section 8) in ways that need resolution before v1.0.

**Consensus verdict**: Ship with changes. The format spec is ready for community review. The tool needs targeted hardening before a 1.0 label.

---

## 2. Individual Reviews

---

### 2.1 Linus Torvalds

**Overall impression**

I said "a git for bugs" in 2007 and I meant something that works like Git does -- local-first, fast, no web UI required, no central server dictating your workflow. Looking at this implementation, the fundamental architecture is correct. Issues are commits. Refs are refs. You push and fetch them like anything else. That is exactly the right level of abstraction. I am not going to pretend this is finished, but the bones are right.

**Strengths**

The single best thing about this project is what it does NOT do. It does not use JSON blobs. It does not invent a custom binary format. It does not require a database. The empty tree trick (`4b825dc642cb6eb9a060e54bf899d15006578022` at `git-issue-create` line 185) means zero disk waste -- every issue commit carries data purely in the message. The `git for-each-ref` one-liner in Section 5.2 of the spec is exactly how this should work. No subprocess spawning. No parsing. Just Git's own format strings.

The UUID decision was correct. Sequential IDs in a distributed system are insane. The 7-character abbreviation is the right UX compromise.

**Concerns**

The `git-issue-ls` script (lines 91-165) runs `git log` inside a `while read` loop for *every single issue*. For each issue, it spawns `git rev-list --max-parents=0` to find the root, then `git log --format='%(trailers:...)'` to extract state. That is O(n) process spawns where n is the number of issues. At 500 issues this will be noticeably slow. At 5,000 it will be unusable. The spec's own Section 5.2 shows how to do this with a single `git for-each-ref`, but the implementation does not actually use that approach because `for-each-ref` gives you the TIP commit's subject (the latest comment), not the root commit's subject (the title). This is a fundamental tension in the data model that needs resolution.

The `resolve_issue()` function is duplicated verbatim in `git-issue-edit` (line 38), `git-issue-show` (line 21), `git-issue-comment` (line 20), and `git-issue-state` (line 26). That is four copies of the same function. Extract it to a shared library file. This is basic software hygiene.

I do not like that `git-issue-comment` (lines 93-99) has an empty case branch for multi-line comment injection checking. The comment says "Multi-line is OK for comments, but check for trailer injection" and then does *nothing*. Either validate or do not, but an empty handler that claims to check something is worse than no check at all.

**Recommendations**

1. Extract `resolve_issue()` and `validate_no_newlines()` into a shared `git-issue-lib` that all commands source.
2. Solve the title-from-root performance problem. Consider caching the title in a trailer on the tip commit, or accept that `ls` must use the slower path but optimize it with `git for-each-ref --format` and `git cat-file --batch`.
3. Either implement real trailer injection detection in comments or remove the empty case branch.
4. Do not rewrite in another language yet. Shell is fine for proving the format works. Rewrites are premature optimization at this stage.

**Verdict**: Ship with changes.

---

### 2.2 Junio C Hamano (Gitster)

**Overall impression**

I will evaluate this from two angles: as a candidate for eventual inclusion in Git's contrib/ directory or as a format spec that could appear alongside `gitformat-pack(5)` and `gitformat-index(5)`, and as a standalone tool that must meet basic quality standards.

The format spec (ISSUE-FORMAT.md) is surprisingly well-structured for a first draft. It follows the pattern of existing Git format documentation -- abstract, design principles, wire format, compatibility notes. It correctly references RFC 4122, gitformat-trailers, and gitformat-pack. The Security Considerations section (Section 11) shows awareness of injection classes. This is better than most proposals that arrive on the mailing list.

**Strengths**

The spec properly uses MUST/SHOULD/MAY in a manner consistent with RFC 2119, though it does not explicitly reference RFC 2119. Section 10 (Compatibility Notes) is excellent -- explicitly calling out the relationship to git-notes, git-bug, and Fossil saves reviewers the time of asking "why not X?"

The test suite is thorough for the scope. I count 71 core tests and 35 bridge tests covering: basic CRUD, lifecycle, special characters, newline injection rejection, empty body handling, idempotent re-import, round-trip import/export, dry-run modes, error cases, and format compliance. The mock `gh` approach in `test-bridge.sh` is sound -- mocking at the CLI boundary is the right level.

**Concerns**

The spec claims in Section 4.2 that "Comment commits carry no trailers unless they also change issue state." But nowhere does the spec or implementation validate this invariant. A conforming implementation could add arbitrary trailers to comment commits and nothing would catch it. The spec needs to either relax this statement or explicitly define what happens when unexpected trailers appear on comment commits.

The spec references `%(trailers:key=State,valueonly)` format in Section 5 but does not specify minimum Git version requirements. The `%(trailers:...)` format was introduced in Git 2.11 (November 2016). The `valueonly` option was added in Git 2.17 (April 2018). This must be documented.

The `git-issue-create` script at line 188 uses `git commit-tree "$empty_tree" < "$tmpfile"` without `--` before the tree argument. While not exploitable in this specific context (the empty tree hash is a fixed string), the general pattern should use `--` for consistency with the spec's own Section 11.3 which mandates "Use `--` end-of-options markers in all git commands that accept user-supplied arguments."

The `git-issue-edit` script at line 245 uses `sed` with a user-supplied label value directly in the pattern: `sed "s/, *$rl//g;..."`. If a label contains regex metacharacters (e.g., `C++`, `bug.fix`), this will behave incorrectly or fail silently. Labels with `.`, `*`, `+`, `[`, `]` characters will produce wrong results.

There is no `#!/bin/sh` portability verification. The scripts use `$(...)` command substitution (POSIX-compliant) but also `test $# -ge 2` without quoting (safe but brittle), `sed '/^$/d'` (portable), and `case` statements (good). However, the fallback UUID generator at `git-issue-create` lines 130-137 uses `od -x` and `awk` with `substr()` in a way that is not portable across BSD and GNU `od` (different output formats). On some systems, `od -x` outputs different column alignments.

**Recommendations**

1. Add an RFC 2119 reference to the spec preamble.
2. Document minimum Git version: 2.17 or later.
3. Add `--` to all `git commit-tree` and `git update-ref` invocations for defense in depth.
4. Fix the regex metacharacter bug in `git-issue-edit` line 245 -- use `grep -v -F` for literal string matching instead of `sed` substitution.
5. Test the UUID fallback path on Linux (`/proc/sys/kernel/random/uuid`) and verify the `od -x` fallback on both GNU and BSD.
6. Define explicitly what a conforming implementation must do with unrecognized trailers on comment commits.

**Verdict**: Ship with changes.

---

### 2.3 Michael Mure (git-bug creator)

**Overall impression**

I have spent seven years building git-bug, which uses a fundamentally different architecture -- operation-based CRDTs with Lamport clocks stored as JSON operations in Git tree objects. I built that complexity because I believed it was necessary for correct distributed behavior. Looking at this project, I have to honestly assess: was the complexity worth it? For many use cases, no.

The git-issue approach trades mathematical correctness for simplicity. The LWW (last-writer-wins) strategy for state conflicts (ISSUE-FORMAT.md Section 6.2) will produce wrong results in specific scenarios -- if Alice closes an issue at T1 and Bob reopens it at T2, but Bob's clock is slightly behind Alice's, the system records Alice's close as the winner even though it happened first in wall-clock time. git-bug solves this with Lamport clocks. But in practice, I have seen exactly zero bug reports about this class of conflict in seven years. The wall-clock approximation works because humans do not typically race to modify the same issue within milliseconds.

**Strengths**

The three-way set merge for labels (Section 6.3) is genuinely clever. It handles the common case -- two people independently adding different labels -- without CRDTs. The bias toward keeping data (addition wins over removal in case of conflict, Section 6.3 step 4) is the right default. Data loss is worse than data duplication.

The Provider-ID mechanism (`Provider-ID: github:owner/repo#42`) is well-designed. git-bug's bridge implementation uses a similar identity mapping, and I can confirm this is the minimal viable approach for idempotent round-trips. The import code at `git-issue-import` lines 106-121 builds a full Provider-ID index before processing, which is correct -- you need the complete picture to detect duplicates.

The format spec's explicit separation from the tool (Section 1, Principle 5: "Format over tool") is the most important strategic decision. git-bug's format IS whatever git-bug produces. There is no independent spec. This has made interoperability impossible. If git-issue's spec gains adoption, it wins by being the protocol, not the tool.

**Concerns**

The merge rules in Section 6 are specified but NOT IMPLEMENTED. There is no `git issue merge` command. There is no code that performs three-way set merge on labels. There is no LWW resolution code for concurrent state changes. The spec describes what should happen when two clones diverge, but the tool provides no mechanism to actually reconcile divergent refs. This is not a minor gap -- it is the entire distributed story. Without merge, `git fetch origin 'refs/issues/*:refs/issues/*'` will simply overwrite local refs with remote ones (fast-forward) or fail (divergent). The Section 6.6 `Conflict:` trailer and `git issue resolve` command are mentioned but do not exist.

The bridge exports comments by iterating through non-root commits (`git-issue-export` lines 196-218) and filtering out state-change-only commits by pattern-matching the subject line (`case "$cmt_body" in "Close issue"|"Reopen issue"|"Change state to "*)...`). This is extremely fragile. If a user writes `git issue state --close -m "Close issue for now"` with a custom message that starts with "Close issue", the export will skip it. The heuristic should check for trailers, not subject line patterns.

The import does not import GitHub milestones as issues or track milestone lifecycle. More importantly, the import at line 296 writes raw comment body to the commit message without separating subject from body. GitHub comments can be arbitrarily long. A 2000-character comment becomes a 2000-character subject line. Git's tooling will truncate this. The spec says subject line should be max 72 characters.

**Recommendations**

1. Implement `git issue merge` -- even a basic version that handles fast-forward and detects divergence. Without this, the "distributed" claim is aspirational.
2. Fix the comment export heuristic: check for the presence of a `State:` trailer rather than pattern-matching subject lines.
3. For imported comments, extract the first line (or first 72 characters) as the subject and put the rest in the body.
4. Add a warning to the README that merge/sync between clones is not yet implemented.

**Verdict**: Ship with changes.

---

### 2.4 D. Richard Hipp (Fossil creator)

**Overall impression**

I have been maintaining Fossil's ticket system since 2006. It uses immutable "ticket change artifacts" that record field-level deltas, materialized into SQLite tables for querying. Twenty years of production use have taught me what matters: data integrity, queryability, and test coverage. Let me evaluate git-issue against those criteria.

The append-only commit chain model is sound. Each commit is cryptographically linked to its parent by SHA, so history tampering is detectable. This is the same property Fossil's artifact system relies on. The empty tree optimization is elegant -- I wish I had thought of something similar for Fossil's zero-content artifacts.

**Strengths**

The test coverage ratio is impressive: 106 tests for approximately 1,750 lines of shell code (I count the 11 scripts). That is roughly 1 test per 16 lines of code. The tests cover positive paths, negative paths (invalid priority, missing arguments, nonexistent issues), edge cases (empty body, special characters, newline injection), idempotency (re-import, re-export), and format compliance (empty tree, UUID format, trailer presence). This is better test hygiene than most projects I review.

The idempotent round-trip design is well-tested. The bridge test at `test-bridge.sh` lines 329-346 verifies that re-importing the same issues produces no new refs and outputs "skipped" messages. The export test at lines 573-591 verifies that re-exporting syncs rather than duplicates. This is precisely the behavior you need for a bridge that might run on a cron job.

The Makefile is minimal and correct. `install -m 755` for executables, proper `DESTDIR` support for packaging, `.PHONY` targets. No autoconf. No cmake. Just `make install`. I respect this.

**Concerns**

Fossil materializes ticket state into SQLite, which means I can query "show me all high-priority bugs assigned to drh, sorted by creation date" in milliseconds, regardless of repository size. git-issue's `ls` command must walk every ref, spawn `git rev-list` for each to find the root, spawn `git log` to extract state, and optionally extract labels/assignee/priority for filtering. At `git-issue-ls` line 91, the `git for-each-ref | while read` loop spawns at minimum 3 git processes per issue. For a repository with 1,000 issues, that is 3,000+ process spawns. On a cold cache, this will take seconds. Fossil does the same query in <1ms.

The lack of a materialized index is the biggest architectural weakness. Without caching computed state, every listing operation must recompute from first principles. The spec explicitly touts "zero subprocess spawning" in Section 5.2, but the implementation does not deliver on this claim.

The state computation at `git-issue-ls` lines 104-105 uses `git log --format='%(trailers:key=State,valueonly)' "$ref" | sed '/^$/d' | head -1`. This walks the ENTIRE commit chain from HEAD until it finds a non-empty State trailer. For an issue with 500 comments, this reads 500 commit messages. The `head -1` terminates the pipe early, but `git log` may have already done the work. There is no `--max-count=1` or equivalent for "stop at first match."

There is no data integrity check. Fossil has `fossil rebuild` to verify and repair the ticket database. git-issue has no equivalent. A malformed issue (missing `State:` trailer on root, non-UUID ref, wrong tree object) will silently produce wrong output. Consider adding a `git issue fsck` command.

**Recommendations**

1. Add `git issue fsck` that validates: all refs match UUID format, all commits use empty tree, all root commits have `State:` and `Format-Version:` trailers.
2. Consider a materialized state cache in `.git/issue-cache/` (like Git's commit-graph) for fast listing. Invalidate on ref changes.
3. Optimize state computation: walk from HEAD and stop at first `State:` trailer using `git log -1 --format='%(trailers:key=State,valueonly)' <ref>` -- wait, that only checks the tip. Instead, use `git log --format=... | head -1` but add `--no-walk=sorted` or process output incrementally. Actually, the current approach is close to optimal for shell. The real fix is the materialized cache.
4. Add a `git issue search` command for full-text search across issue titles and bodies. `git log --all --grep=` can do this across issue refs.

**Verdict**: Ship with changes.

---

### 2.5 Diomidis Spinellis (git-issue/Spinellis creator)

**Overall impression**

I wrote the original git-issue in 2017 as a practical POSIX shell tool. It survived in a space where most competitors died because of two things: shell portability (works everywhere Git works) and GitHub/GitLab bridges (practical adoption path). Looking at this new git-issue, I see many of the same pragmatic decisions, plus a critical innovation I never attempted: a standalone format specification.

The architecture is better than mine. I used a file-per-field approach (one file for title, one for description, one for tags) stored in a Git branch, which created merge conflicts constantly. The commit-chain-with-trailers approach eliminates that entire class of problems. I wish I had seen this design eight years ago.

**Strengths**

The shell code quality is good. Proper `set -e` at the top of every script. Consistent use of `printf '%s'` instead of `echo` for user content (matching the spec's own Section 11.3 recommendation). The `trap 'rm -f "$tmpfile"' EXIT` pattern for temp file cleanup is correct and consistent across all scripts. The argument parsing is standard POSIX -- `case`/`esac` with `shift`, no bashisms, no GNU getopt dependency.

The bridge implementation is practical. Requiring `gh` and `jq` as external dependencies is the right call -- these are the de facto standard tools for GitHub API interaction. The user cache in `git-issue-import` (lines 147-173) avoids redundant API calls for the same GitHub user across multiple issues. The `resolve_user()` function falls back to `login@users.noreply.github.com` when no public email is available (line 168), which is exactly the GitHub convention.

The idempotent import/export cycle is the single most important feature for practical adoption. My own git-issue's bridge was the #1 requested feature and the #1 source of bugs. Getting this right with Provider-ID tracking is essential, and the test at `test-bridge.sh` lines 739-762 (round-trip import-then-export) validates the full cycle.

**Concerns**

The `resolve_issue()` function iterates all refs to find a prefix match. My git-issue had the same approach initially and it became a bottleneck at around 200 issues. Consider using `git for-each-ref --format='%(refname)' 'refs/issues/<prefix>*'` with a glob pattern instead of iterating and matching in shell. Git's ref backend can do prefix matching much faster than a shell loop.

The `git-issue-import` script has a subshell variable problem. At lines 113-121, the Provider-ID index is built inside a pipeline (`git for-each-ref | while read ... do ... done > "$provider_index"`). In POSIX sh, the `while` loop runs in a subshell because it is on the right side of a pipe. This means any variables set inside the loop are lost when the subshell exits. In this specific case the output is redirected to a file so it works, but the same pattern in `git-issue-export` (line 107, `git for-each-ref | while read`) means the `exported`, `skipped`, and `synced` counters at lines 101-103 are never updated. The final summary line at line 237 acknowledges this: "Note: counts from subshell not available here." This is a known bug. Fix it by redirecting the `for-each-ref` output to a file and reading from it, or use a here-document with `while read ... done < <(...)` -- except that is a bashism. The POSIX approach: `git for-each-ref > "$tmpfile"` then `while read ... done < "$tmpfile"`.

The export's body extraction at line 117 (`sed '/^[A-Z][A-Za-z-]*: /d'`) strips any line that looks like a Git trailer. If an issue body contains text like "State: this is confusing" or "Priority: getting these reviews done," it will be silently stripped. This is a real problem for issues imported from GitHub where users write free-form text.

The `git-issue-init` script only supports a remote named `origin` (line 38). Many workflows use different remote names (`upstream`, `fork`, etc.). Consider accepting an optional remote name parameter.

**Recommendations**

1. Fix the subshell counter bug in `git-issue-export`. Restructure the loop to avoid the pipeline subshell.
2. Use `git for-each-ref 'refs/issues/<prefix>*'` with a glob for prefix matching instead of shell-side filtering.
3. Fix body extraction to use `git interpret-trailers --parse` to identify actual trailers rather than regex-based stripping.
4. Allow `git issue init [remote-name]` to support non-origin remotes.
5. Add `git issue version --format` (at least `--short` and `--json`) for scripting.

**Verdict**: Ship with changes.

---

### 2.6 Jeff King (Peff)

**Overall impression**

I spend most of my time inside Git's ref handling, pack format, and transport protocol code at GitHub. The first thing I evaluate with any proposal that uses custom ref namespaces is: what happens when this interacts with the rest of Git's infrastructure? Reftable? Pack-refs? Fetch negotiation? Advertisement? The good news is that `refs/issues/*` is a clean namespace that does not collide with anything in Git's current design. The bad news is that there are performance and transport implications that this project has not fully considered.

**Strengths**

Using proper refs under `refs/issues/` instead of notes, loose files, or a custom database is the single most important architectural decision. It means:
- Reftable backend compatibility for free (confirmed in spec Section 10.4, and correct).
- `git gc` handles object reachability correctly because commits are referenced by refs.
- `git fsck` can validate the commit chain integrity.
- Transport protocol already knows how to push/fetch arbitrary refs.

The empty tree optimization is correct. Since all issue commits share the same tree object, there is exactly one tree object in the repository regardless of how many issues exist. This is optimal for pack files.

The refspec configuration in `git-issue-init` (line 46: `+refs/issues/*:refs/issues/*`) is the right approach. The `+` force-update prefix is necessary because issue refs will be updated (new commits appended), and without it a non-fast-forward update during fetch would fail.

**Concerns**

The biggest concern is ref advertisement cost. When a Git client connects to a server, the server advertises ALL refs (in protocol v0/v1) or the client can request specific ref prefixes (in protocol v2 with `ref-prefix`). A repository with 10,000 issues has 10,000 refs under `refs/issues/`. In v1 protocol, every `git fetch` will advertise all 10,000 issue refs even if you only want to fetch code. This adds approximately 50 bytes per ref (SHA + refname) = 500KB of overhead on every fetch. With protocol v2, clients can use `ref-prefix refs/heads/` to avoid this, but many deployments still use v1.

GitHub currently does NOT display or serve `refs/issues/*` in any special way. A push of `refs/issues/*` to GitHub will create server-side refs that are technically accessible but invisible in the UI. More problematically, GitHub's ref storage has per-repository limits. At scale (>50,000 refs), repository operations slow down. I have seen this with repositories that accumulate refs from CI systems. 10,000 issues with 10 comments each means 10,000 refs (manageable) but the commit chains create deep history that `git gc` must traverse.

The `git-issue-import` script at lines 272-275 sets `GIT_AUTHOR_DATE` to the original issue creation timestamp but does NOT set `GIT_COMMITTER_DATE`. This means the committer date is always "now" (import time) while the author date is the original. This is standard Git practice (e.g., `git am`, `git cherry-pick`), so it is technically correct, but it means `git log --format='%ci'` and `git log --format='%ai'` give different timestamps, which could confuse tools that use committer date for ordering.

The `update-ref` calls use the compare-and-swap pattern correctly (`git update-ref "$issue_ref" "$commit" "$issue_head"` at `git-issue-edit` line 328, `git-issue-state` line 223, `git-issue-comment` line 142). This prevents lost updates if two concurrent processes modify the same issue. Good.

However, there is a TOCTOU race between reading the current HEAD (`git rev-parse "$issue_ref"`) and the `update-ref`. If another process updates the ref between those two calls, the `update-ref` will fail with a "reference already changed" error. The scripts do not handle this error -- `set -e` will simply abort. This is acceptable for a local tool (concurrent modification of the same issue is rare) but should be documented.

**Recommendations**

1. Document the ref advertisement cost and recommend Git protocol v2 (`git config protocol.version 2`) for repositories with many issues.
2. Consider a `refs/issues/heads` summary ref that contains a tree mapping UUID-to-current-SHA, allowing a single ref to represent the state of all issues. This would reduce ref count from O(n) to O(1) for advertisement purposes. This is a v2 format consideration.
3. Add error handling for `update-ref` failures (TOCTOU race). Retry with the new HEAD value, or at minimum print a helpful error message.
4. Consider using `git for-each-ref --sort=-committerdate` for chronological listing, avoiding the need to extract dates separately.
5. Add a note to the spec about GIT_COMMITTER_DATE behavior during import.

**Verdict**: Ship with changes.

---

### 2.7 Emily Shaffer

**Overall impression**

I have been involved in Git's governance process, hooks system, and community interactions at Google. My evaluation focuses on: Is the format spec ready for submission to the Git mailing list? Does the project have a realistic path to community adoption? Are there governance or process concerns?

The format spec is genuinely the best part of this project, and the strategic insight -- that the spec, not the tool, is the deliverable -- is correct. Every previous distributed issue tracker failed because adoption required switching tools. A blessed format spec means any tool can implement it, and platforms like GitHub/GitLab/Forgejo could add native support.

**Strengths**

The spec follows established Git documentation conventions. Sections map to existing gitformat-* man pages: abstract, wire format, computation rules, transport, compatibility. The acknowledgments section (ISSUE-FORMAT.md line 589) properly credits prior art. The references section includes formal RFC links. This is more polished than most initial RFCs that arrive on the mailing list.

The Design Principles section (Section 1) explicitly states "Simple over clever" and "Format over tool" -- these align with the Git community's values. Junio and the Git community are deeply skeptical of complexity for complexity's sake. Leading with simplicity is strategically correct.

The test suite uses Git's own testing patterns (shell-based, `test` builtins, no external test framework dependencies). While it does not use Git's `test-lib.sh` framework directly, the structure is similar enough that porting would be straightforward. The mock `gh` approach in bridge tests is clean and self-contained.

**Concerns**

The spec has no formal versioning or change process. Section 12 says "Extensions MUST increment the Format-Version: trailer" but does not define who controls the version number, how backwards compatibility is maintained, or what the review process is for spec changes. For a format intended to be a community standard, this governance gap is critical. Compare with the Git wire protocol documentation, which has explicit versioning and upgrade negotiation.

The spec uses indefinite language in several places that would not survive mailing list review. Section 6.6 says "Implementations SHOULD provide a `git issue resolve` command" -- but this conflates format specification with tool requirements. A format spec should define the data model for conflict representation, not mandate specific command names. Similarly, Section 2.1 says "Implementations SHOULD support abbreviated identifiers" -- that is a tool concern, not a format concern.

The spec does not address access control or permission models. In a corporate environment, who can create issues? Who can close them? The commit author field provides identity but not authorization. This is fine for the open-source use case but limits corporate adoption. It should be acknowledged in a "Non-Goals" or "Limitations" section.

The project has no CONTRIBUTING.md, no CODE_OF_CONDUCT.md, and no mailing list or discussion forum. For a project that aims to become a community standard, there is no community infrastructure. The prior art research identified that "non-dev exclusion" was a root cause of failure for previous tools. This project currently offers zero accommodation for non-developers.

The README at line 229 says "87 tests: 55 core + 32 bridge" but the actual counts are 71 core + 35 bridge = 106. The README is out of date. This kind of inconsistency erodes trust in a spec submission.

**Recommendations**

1. Separate the format spec from tool requirements. Remove all "Implementations SHOULD provide a `git issue <command>`" language. The spec should define data formats and computation rules, not UX.
2. Add a "Governance" or "Change Process" section to the spec, or a separate GOVERNANCE.md.
3. Add an explicit "Non-Goals" section to the spec: access control, real-time sync, binary attachments (for v1).
4. Create a CONTRIBUTING.md with the submission strategy: mailing list post format, review process, how to propose spec changes.
5. Fix the test count discrepancy in README.md.
6. Before submitting to git@vger.kernel.org, prepare a cover letter that frames this as an RFC, explicitly asks for feedback (not merge), references the prior art, and acknowledges the spec-vs-tool distinction. Study how gitformat-bundle(5) and gitformat-commit-graph(5) were introduced.

**Verdict**: Ship with changes.

---

## 3. Structured Debate: Three Critical Questions

---

### Q1: "Is the shell implementation sufficient for a v1.0 release, or does it need a C/Go/Rust rewrite before serious adoption?"

**Linus**: Shell is fine. Git itself started as shell scripts. I wrote the first version of Git in shell and C, and the shell parts worked for months before they were rewritten. The point of shell is that it is the universal runtime -- if you have Git, you have `/bin/sh`. A rewrite before proving the format works is premature optimization. Ship the shell version, get users, THEN decide if performance matters.

**Junio**: I partially agree with Linus, but with caveats. The shell implementation has correctness issues (the regex metacharacter bug in `git-issue-edit` line 245, the subshell counter bug in `git-issue-export`) that are not performance problems -- they are bugs that happen to be easy to write in shell and hard to avoid without a type system. For inclusion in Git's contrib/, I would require stricter POSIX compliance testing. For a standalone tool, shell is acceptable for v1.0 if the bugs are fixed.

**Peff**: My concern is not the language but the process spawning. The `git-issue-ls` command spawns 3+ git processes per issue. At GitHub scale (repositories with 100K+ issues), this is a non-starter. But at GitHub scale you would not use the shell tool -- you would have native server-side support based on the format spec. So the question is: what scale does the shell tool need to handle? If the answer is "developer's personal projects up to ~500 issues," shell is fine. If the answer is "the Linux kernel's 60,000+ closed bugs," you need C or Go.

**Hipp**: For reference, Fossil's ticket system handles 20,000+ tickets instantly because they are materialized into SQLite. The shell tool will hit a wall at around 1,000 issues. But I agree with Linus -- ship the shell version now. The format spec is the priority. A Go implementation can come later.

**Mure**: git-bug started in Go from day one because I knew shell would not scale. But seven years later, git-bug has ~10K stars and the format is still whatever my Go code produces. This project has the opposite problem: great spec, simple implementation. That is a better position to be in. Keep shell for v1.0.

**Spinellis**: My git-issue has been shell for 8 years and works fine for its users. The ceiling is around 500-1,000 issues before `ls` becomes sluggish. For an initial release aimed at proving the format, shell is absolutely sufficient. The adoption bottleneck is not performance -- it is awareness and trust in the format.

**Emily**: The rewrite question is a distraction from the real priority: getting the format spec reviewed by the Git community. A C rewrite takes months. A mailing list RFC takes days. Do the RFC first. If the community says "we will only evaluate this with a C implementation," then rewrite. Do not spend months on a rewrite that the community might reject for unrelated reasons.

**CONSENSUS**: Shell is sufficient for v1.0. The format spec is the priority. Target the shell implementation at <1,000 issues. Plan a Go or C implementation for v2.0 after the format spec has community feedback. Fix the existing correctness bugs regardless.

---

### Q2: "Does the bridge implementation violate the spec's own bridge protocol (Section 8)? Should the GitHub bridge use the text protocol or is direct `gh` CLI integration the pragmatic choice?"

**Junio**: This is a clear spec violation. Section 8 defines a bridge protocol with `git-issue-remote-<provider>` executables that speak a line-oriented text protocol on stdin/stdout. The actual implementation in `git-issue-import` and `git-issue-export` hardcodes `gh` CLI calls directly. There is no `git-issue-remote-github` executable. The spec promises a protocol that does not exist. Either implement the protocol or remove Section 8 from the spec.

**Spinellis**: I disagree with removing Section 8. The protocol design is good -- it is the same pattern as Git's `git-remote-<transport>` helper protocol. The implementation just has not caught up yet. The pragmatic path is: keep Section 8 as a v2 goal, mark it as "Future" or "Planned," and document that the current GitHub bridge is a direct integration that will be refactored to use the protocol later. Do not remove good design just because it is not implemented yet.

**Mure**: I have built bridges for GitHub, GitLab, JIRA, and Launchpad in git-bug. The plugin protocol approach is correct for long-term extensibility. But the direct `gh` integration is how you get users NOW. Nobody is going to implement a custom text protocol bridge before the tool has 1,000 users. Ship the direct `gh` integration as the pragmatic v1.0 bridge, and implement the protocol when a second provider (GitLab) is needed.

**Linus**: A spec should not include things that are not implemented. That is how specs become lies. Either implement Section 8 or move it to a "Future Directions" appendix with a clear "NOT IMPLEMENTED" label. The current state is misleading -- someone reading the spec would expect `git-issue-remote-github` to exist and be confused when they cannot find it.

**Peff**: From a Git integration perspective, the `git-remote-<transport>` helper protocol is one of the most successful extension points in Git. Modeling the bridge protocol after it is strategically sound. But the current implementation does not even attempt to match the protocol. The `git-issue-import` and `git-issue-export` commands should be thin wrappers that call `git-issue-remote-github` which speaks the text protocol internally. This way, the protocol is exercised even if there is only one provider.

**Emily**: The spec-vs-implementation gap here is the most dangerous kind: it is a promise to third-party implementers that is not tested. If someone reads Section 8 and builds a GitLab bridge using the text protocol, they will discover it does not work because nothing in the tool calls the protocol. Add an integration test that verifies the text protocol end-to-end, even if the only implementation is the GitHub bridge.

**Hipp**: Move Section 8 to a separate document. The ISSUE-FORMAT.md should define the data format. The bridge protocol is a tool concern, not a format concern. Fossil's ticket system does not define an import/export protocol in the artifact format specification -- it defines it in the sync protocol documentation. Same principle applies here.

**CONSENSUS**: The current direct `gh` integration is acceptable for v1.0 but the spec must not promise what does not exist. Move Section 8 (Bridge Protocol) to either a separate BRIDGE-PROTOCOL.md document or an appendix marked "Status: Planned -- Not Yet Implemented." The v1.0 spec should describe the Provider-ID mechanism (Section 9) without mandating a specific bridge protocol. Plan to implement the text protocol when the second provider (GitLab) is added. **Dissent**: Peff argues for implementing the protocol now with a single provider to validate the design; the majority considers this premature.

---

### Q3: "What's the realistic path to getting ISSUE-FORMAT.md blessed by the Git project? What needs to change in the spec or implementation?"

**Junio**: Let me be direct. The Git project does not have a formal RFC process. We have a mailing list where patches are reviewed. A format spec would need to be submitted as a patch that adds a new man page -- something like `gitformat-issue(5)` -- to the `Documentation/` directory in the Git source tree. To have any chance of acceptance:

1. The spec must be in Git's documentation format (AsciiDoc, not Markdown).
2. It must be submitted as part of a patch series that includes at least a basic implementation in C or shell that lives in `contrib/`.
3. It must survive multiple rounds of mailing list review, possibly over months.
4. I would need to see broad support from at least 2-3 active Git contributors before merging.
5. The spec must NOT reference any specific external tool (no "git-issue" by name). It defines a format; tools implement it independently.

Realistically, this is a 6-12 month process if the spec is well-received, and it may never happen if there is not enough community interest. The Git project has never added a new ref namespace standard. `gitformat-pack` and `gitformat-index` document existing internal formats, not new ones.

**Emily**: Junio's assessment is accurate but I want to add context. The Git community is more open to new proposals than its reputation suggests, but the proposal must be framed correctly. Do NOT submit this as "please merge my issue tracker." Submit it as "here is a format spec for storing issue data in Git objects, requesting feedback." The tone matters enormously. Study how the commit-graph format was introduced -- it was proposed, debated for months, revised multiple times, and eventually accepted because it solved a real performance problem with broad support.

The biggest obstacle is not the spec quality -- it is demonstrating demand. If you can show that 5+ independent implementations exist (even toy ones), or that 2+ hosting platforms are interested, the argument for standardization becomes compelling. Consider reaching out to Forgejo/Codeberg and Gitea maintainers first. They are more agile than GitHub/GitLab and more likely to experiment.

**Linus**: I am going to say something unpopular: you might not need Git project blessing at all. Git does not own the ref namespace. Any tool can create `refs/whatever/*`. If enough tools and platforms adopt `refs/issues/*` with this format, it becomes a de facto standard regardless of whether it appears in Git's man pages. The web was not standardized by a committee before it won. HTTP was a fait accompli that IETF formalized after the fact. Focus on adoption, not approval.

**Peff**: Linus has a point about de facto standards, but there is a practical reason to seek Git project acknowledgment: ref advertisements. If `refs/issues/*` becomes common, Git's protocol might benefit from special-casing it (e.g., optional advertisement, separate negotiation). That requires upstream awareness at minimum. I would recommend posting an informational RFC to the mailing list -- not a patch series, just a "here is what we are doing, here is the spec, we would appreciate feedback" email. This puts the community on notice without asking for a merge.

**Hipp**: The Fossil approach was different. We did not seek external blessing; we built the ticket system, used it for Fossil's own development, and let adoption speak for itself. Fossil's ticket system has been running for 20 years because it works, not because anyone standardized it. If git-issue works well enough that projects actually use it, standardization follows naturally. If it does not work well enough, no amount of standardization will help.

**Mure**: As someone who tried and failed to get git-bug's format recognized by anyone, I strongly agree with the "adoption first" strategy. The Git mailing list will not standardize a format without proven demand. Get 100 projects using `refs/issues/*` with this format, THEN submit the spec. At that point, the question becomes "should Git formally support what people are already doing?" and the answer is almost always yes.

**Spinellis**: The D+C (Defect + Control) strategy from the previous council was: standalone tool, then format spec, then ecosystem adoption. The spec submission to the mailing list is Step 2. But Step 2 requires Step 1 to be solid. I would recommend: ship v1.0 with a polished spec, get 6 months of real-world usage, fix whatever breaks, THEN submit to the mailing list with a cover letter that includes: the spec, usage data, links to 2-3 independent implementations, and endorsements from at least one hosting platform.

**CONSENSUS**: The realistic path is a multi-phase approach:

1. **Now (v1.0)**: Ship the tool and spec. Convert spec to AsciiDoc format as an alternative rendering. Remove tool-specific language from the spec.
2. **Months 1-6**: Seek adoption. Dogfood on the git-issue project itself. Reach out to Forgejo/Codeberg for experimental platform support. Encourage independent implementations.
3. **Month 6+**: Post an informational RFC to git@vger.kernel.org. Frame as "here is a format spec with N users and M implementations, requesting feedback." Do NOT submit as a patch series initially.
4. **Month 12+**: If there is positive reception, submit as a formal `gitformat-issue(5)` patch series with a `contrib/git-issue/` implementation.

**Dissent**: Linus argues that seeking mailing list approval is unnecessary if adoption is strong enough. The majority view is that formal recognition, while not strictly necessary, significantly accelerates platform adoption and signals legitimacy.

---

## 4. Consensus Recommendations

Prioritized by urgency and impact. Dissenting opinions noted.

### P0 -- Must fix before v1.0

1. **Fix the regex metacharacter bug in `git-issue-edit` line 245**. Labels containing `.`, `*`, `+`, `[`, etc. will produce incorrect results when using `--remove-label`. Use `grep -v -F` or awk for literal string matching.

2. **Fix the subshell counter bug in `git-issue-export`** (acknowledged on line 237). The `while read` loop runs in a subshell due to the pipeline, so `exported`/`skipped`/`synced` counters are never updated. Restructure to avoid the pipeline.

3. **Fix the comment export heuristic in `git-issue-export` lines 203-204**. The subject-line pattern match (`"Close issue"|"Reopen issue"|...`) is fragile. Check for the presence of a `State:` trailer instead.

4. **Fix the empty comment injection check in `git-issue-comment` lines 93-99**. Either implement actual trailer injection validation for multi-line comments (check if any line in the body matches the trailer pattern) or remove the empty case branch.

5. **Extract shared functions** (`resolve_issue()`, `validate_no_newlines()`, empty tree computation) into a single `git-issue-lib` sourced by all commands. Four copies of `resolve_issue()` is a maintenance liability.

6. **Update README.md test counts** (line 229 says 87, actual is 106).

### P1 -- Should fix before v1.0

7. **Resolve the spec-vs-implementation gap for Section 8 (Bridge Protocol)**. Move Section 8 to a separate document or mark it as "Status: Planned." The current spec promises a protocol that does not exist.

8. **Add minimum Git version requirement to the spec**: Git 2.17 or later (for `%(trailers:key=...,valueonly)` support).

9. **Add RFC 2119 reference** to the spec preamble for MUST/SHOULD/MAY.

10. **Remove tool-specific language from the spec**. Replace "Implementations SHOULD provide a `git issue resolve` command" with "Implementations SHOULD provide a mechanism for manual conflict resolution." The spec defines data, not UX.

11. **Handle imported comment formatting**: extract first line (max 72 chars) as subject, remainder as body. Currently, long GitHub comments become arbitrarily long subject lines.

12. **Improve `resolve_issue()` performance**: use `git for-each-ref 'refs/issues/<prefix>*'` glob matching instead of shell-side iteration.

### P2 -- Should address before ecosystem push

13. **Implement `git issue merge`** or at minimum `git issue merge --check` that detects divergent refs and reports conflicts. Without this, the "distributed" claim is aspirational. *(Dissent: Linus considers this premature; Mure and Hipp consider it essential.)*

14. **Add `git issue fsck`** that validates ref format, empty tree usage, required trailers, and Format-Version presence.

15. **Fix body extraction in `git-issue-export` line 117**: use `git interpret-trailers --parse` to identify trailers rather than regex-based stripping, to avoid stripping body lines that look like trailers.

16. **Add `--` end-of-options markers** to all `git commit-tree` and `git update-ref` invocations for consistency with spec Section 11.3.

17. **Document ref advertisement cost** and recommend `protocol.version=2` for repositories with many issues.

18. **Allow `git issue init [remote-name]`** to support non-origin remotes.

### P3 -- Future considerations

19. **Materialized state cache** (`.git/issue-cache/`) for fast listing at >500 issues.
20. **`git issue search`** for full-text search across issues.
21. **Convert spec to AsciiDoc** for eventual inclusion in Git documentation.
22. **CONTRIBUTING.md and community infrastructure** for open governance.
23. **Non-Goals section** in the spec (access control, real-time sync, binary attachments).

---

## 5. Comparison to Previous Council Decisions

The previous 5-debate council established architecture decisions for v2. Here is how the implementation maps to each:

### Decision 1: Identity -- UUIDs with 7-char abbreviated display

**Implementation**: Fully compliant. `git-issue-create` lines 122-137 generate UUIDv4 with three fallback methods (uuidgen, /proc, od+awk). Line 140 computes the 7-character short ID. The test at `test-issue.sh` lines 108-118 validates UUID format. `resolve_issue()` handles prefix matching with ambiguity detection (`git-issue-show` lines 66-76).

**Assessment**: Correct. The only concern is the portability of the `od -x` fallback (raised by Junio).

### Decision 2: Data model -- Git trailers, subject-line-as-title, Format-Version

**Implementation**: Fully compliant. All scripts use `git interpret-trailers --in-place` for trailer management (e.g., `git-issue-create` lines 160-182). The root commit subject is the title. `Format-Version: 1` is always the last trailer added. The `Title:` trailer for override in subsequent commits is implemented in `git-issue-edit` lines 296-299.

**Assessment**: Correct. The only deviation is that the implementation adds trailers one at a time via multiple `git interpret-trailers` calls rather than a single call with multiple `--trailer` arguments. This is functionally equivalent but slightly slower.

### Decision 3: Scope -- D+C strategy (standalone tool, then format spec, then ecosystem)

**Implementation**: On track. The standalone repository exists. The format spec is complete. The tool is functional. Ecosystem adoption has not begun, which is expected at v0.2.

**Assessment**: Correct. The spec's inclusion of an unimplemented bridge protocol (Section 8) slightly undermines the "format over tool" principle by conflating format specification with tool protocol specification.

### Decision 4: Merge -- Field-specific (comments=union, state=LWW, labels=three-way set merge)

**Implementation**: SPECIFIED BUT NOT IMPLEMENTED. The spec (Sections 6.1-6.6) correctly defines all merge rules. However, no `git issue merge` command exists. No code performs three-way set merge on labels. No code implements LWW tiebreaking by SHA for equal timestamps. The distributed merge story is entirely theoretical at this point.

**Assessment**: This is the most significant gap between decision and implementation. The merge rules were the centerpiece of the v2 architecture debate, and they exist only on paper. This is acceptable for v0.2 but MUST be addressed before any claim of "distributed" operation.

### Decision 5: Bridge -- Plugin protocol + import/export only in v1

**Implementation**: Import/export is implemented and working. The plugin protocol is specified but not implemented. The direct `gh` CLI integration works as a pragmatic alternative. Round-trip idempotency is tested and working.

**Assessment**: Partially compliant. The "import/export only in v1" requirement is met. The "plugin protocol" requirement is not. The deviation is justified -- direct integration was the pragmatic choice -- but the spec should not claim the protocol exists when it does not.

---

## 6. Roadmap Assessment

Based on the council's review, the recommended priorities for the next three iterations:

### v0.3 (Bug Fix + Hardening Release)

**Goal**: Fix all P0 and P1 issues. Make the tool correct.

1. Fix the 5 bugs identified in P0 (regex metacharacter, subshell counter, comment export heuristic, empty injection check, shared library extraction).
2. Update README test counts.
3. Resolve the Section 8 spec gap (move to separate document or mark as planned).
4. Add RFC 2119 reference, Git version requirement, and remove tool-specific language from spec.
5. Fix imported comment formatting (subject/body split).
6. Optimize `resolve_issue()` with ref glob.

**Estimated scope**: 2-3 days of focused work.

### v0.4 (Distributed Story Release)

**Goal**: Implement the merge rules. Make "distributed" real.

1. Implement `git issue merge <ref>` that handles:
   - Fast-forward (trivial case)
   - Divergent chains with automatic resolution (LWW for state, three-way set merge for labels, union for comments)
   - Conflict detection with `Conflict:` trailer
2. Implement `git issue fsck` for data integrity validation.
3. Add integration tests for multi-clone scenarios (two repos, independent edits, fetch + merge).
4. Fix body extraction to use `git interpret-trailers --parse`.
5. Add `--` to all git plumbing commands.

**Estimated scope**: 1-2 weeks of focused work.

### v1.0 (Community Release)

**Goal**: Ready for public announcement and mailing list RFC.

1. Convert spec to AsciiDoc format (alternative rendering for Git community).
2. Add CONTRIBUTING.md with submission strategy.
3. Add Non-Goals section to spec.
4. Dogfood: use git-issue for the git-issue project's own issue tracking.
5. Reach out to Forgejo/Codeberg for experimental `refs/issues/*` support.
6. Write the mailing list RFC cover letter.
7. Consider implementing the bridge text protocol with the GitHub provider as proof-of-concept.
8. Performance baseline: document expected performance at 100, 500, and 1,000 issues.
9. Add man pages for all commands.

**Estimated scope**: 4-6 weeks, including community outreach.

---

*Council review completed 2026-02-07. All panelists participated in character with their documented expertise and known technical positions. Disagreements were genuine and are noted inline.*
