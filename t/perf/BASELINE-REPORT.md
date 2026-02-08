# git-issue Performance Baseline Report

**Date**: 2026-02-07
**Machine**: Apple M4, macOS 15.7.4 (Sequoia)
**Version**: 0.5.0 (pre-optimization)

## Core Command Benchmarks

| Command | 100 issues | 500 issues | 1000 issues | Scaling |
|---------|-----------|-----------|------------|---------|
| `ls --all` | 7.3s | 80.6s | 165.0s | ~O(n) linear, 165ms/issue |
| `ls (open only)` | 6.9s | ~64s | ~130s (est) | ~O(n) |
| `search` | 3.4s | 36.3s | 74.1s | ~O(n) linear, 74ms/issue |
| `fsck` | 3.7s | 44.0s | 118.5s | ~O(n×c) where c=commits |
| `fsck --quiet` | 3.8s | ~44s | ~118s | Same as fsck |
| `show` | 0.12s | 0.12s | 0.12s | O(c) per issue |

## Merge Benchmarks (200 shared + 30 new + 50 diverged)

| Command | Time |
|---------|------|
| `merge --check` | 13.5s |
| `merge (full, 50 three-way merges)` | 29.0s |

## Import Benchmarks (mock GitHub API, 500 issues)

| Command | Time | Rate |
|---------|------|------|
| `import` (500 issues, ~2.5 comments avg) | 87.7s | 5.7 issues/sec |
| `re-import` (500 skipped, idempotent) | 7.0s | 71 issues/sec |

## Repo Generation Rate

| Scale | Time | Rate |
|-------|------|------|
| 100 issues (max 10 comments) | 4s | 20/sec |
| 500 issues (max 10 comments) | 23s | 20/sec |
| 1000 issues (max 5 comments) | 136s | 7/sec |

## Root Cause Analysis

### Why is `ls` so slow? (165ms per issue)

Per issue, `ls` spawns approximately **22 subprocesses**:

1. `get_issue_title()` → `git log` (trailers) + `sed` + `head` + `git rev-list` + `git log` (subject) = **5 processes**
2. State lookup → `git log` + `sed` + `head` = **3 processes**
3. Labels lookup → `git log` + `sed` + `head` = **3 processes** (even if not filtering)
4. Assignee lookup → `git log` + `sed` + `head` = **3 processes**
5. Priority lookup → `git log` + `sed` + `head` = **3 processes**
6. Milestone lookup → `git log` + `sed` + `head` = **3 processes**
7. Sort key → `git rev-list` + `git log` = **2 processes**

**At 1000 issues: ~22,000 subprocess forks.**

### Why is `search` slower than expected? (74ms per issue)

Per issue:
- `get_issue_title()` = 5 processes
- State lookup = 3 processes
- `git log --format='%s%n%b'` = 1 process
- `grep` = 1 process
- Total: **~10 processes per issue → 10,000 forks at 1000 issues**

### Why is `fsck` the slowest? (118ms per issue)

Per issue:
- `git rev-list $ref` = 1 process (but lists ALL commits)
- **Per commit**: `git log -1 --format='%T'` = 1 process
- With avg 5 commits/issue → 5 git log calls per issue
- Root checks: `git rev-list --max-parents=0` + `wc` + `head` + 2× `git log -1` + 2× `sed`
- Total: **~12 + N(commits) processes per issue**

### Why is `merge` moderate? (50 diverged in 29s)

Per diverged issue:
- 15× `get_trailer_val` (5 fields × 3 versions) = **45 processes**
- Label three-way merge: 12 temp files + 6× `comm` + 6× `sort` + 4× `sed` = **~28 processes**
- Git operations: `commit-tree` + `update-ref` + `interpret-trailers` = **~8 processes**
- Total: **~80 processes per diverged issue**

## Optimization Targets (by impact)

### P0: Batch trailer extraction (ls, search, fsck)
**Expected speedup: 10-20×**

Replace per-issue `git log --format='%(trailers:key=X,valueonly)'` calls with a single
`git for-each-ref` that extracts all needed data in one pass.

```sh
# BEFORE: 5 separate git log calls per issue
state="$(git log --format='%(trailers:key=State,valueonly)' "$ref" | sed '/^$/d' | head -1)"
labels="$(git log --format='%(trailers:key=Labels,valueonly)' "$ref" | sed '/^$/d' | head -1)"
...

# AFTER: 1 git-log call per issue that extracts everything
git log --format='%H %s %(trailers:key=State,valueonly)%x09%(trailers:key=Labels,valueonly)%x09...'
```

Or even better, use `git for-each-ref` with `%(contents:trailers)` to batch all issues.

### P1: Use git cat-file --batch for fsck
**Expected speedup: 5-10×**

Replace per-commit `git log -1 --format='%T'` with a single pipe to `git cat-file --batch`.

### P2: Reduce sed/cut/head forks
**Expected speedup: 2-3×**

Replace `sed '/^$/d' | head -1` chains with shell builtins or single `awk` calls.
Many `printf '%s' "$var" | cut -c1-7` can be replaced with `${var%${var#???????}}`.

### P3: Single-pass commit walk for merge
**Expected speedup: 3-5× for diverged merges**

Instead of 15 separate `git log` calls for trailer extraction during merge,
walk the commit chain once and extract all trailers in a single pass.

## Post-Optimization Results

| Command | 500 issues (before) | 500 issues (after) | 1000 issues (after) | Speedup |
|---------|--------------------|--------------------|---------------------|---------|
| `ls --all` | 80.6s | **3.3s** | **7.3s** | **24×** |
| `search` | 36.3s | **3.3s** | **7.4s** | **11×** |
| `fsck` | 44.0s | **3.3s** | **10.5s** | **13×** |
| `merge` (50 diverged) | 29.0s | — | **9.6s** | **3×** |

### Optimization technique

Replaced per-issue `git log | sed | head` chains (5-22 subprocess forks per issue)
with single `git log --format='%(trailers)' | awk` pipelines (1 fork per issue +
1 awk process total). Trailer values extracted from `Key: Value` lines in awk,
avoiding the newline problem with `%(trailers:key=...,valueonly)` format.
