# Git Issue Format Specification

**Version**: 1
**Status**: Draft
**Author**: Emerson Soares <remenoscodes@gmail.com>
**Date**: 2025-04-23

---

## Abstract

This document specifies a format for storing issue tracking data natively
in Git repositories using only Git's existing object model: commits,
refs, and trailers. The format requires no external database, no custom
binary format, and no tools beyond Git's standard plumbing commands.

Issues are stored as chains of commits under the `refs/issues/` namespace.
Each commit's subject line, body, and trailers carry structured issue data.
The format is designed for distributed operation with deterministic
conflict resolution, enabling issues to travel with the repository across
hosting providers via standard `git push` and `git fetch`.

---

## 1. Design Principles

1. **Git-native**: Use only Git's existing primitives (commits, refs,
   trailers, trees). No custom binary formats, no JSON, no external
   databases.

2. **Distributed-first**: Any operation that works locally must also work
   correctly when repositories are merged from multiple clones with no
   central coordinator.

3. **Tooling-friendly**: Issue metadata must be queryable using standard
   Git plumbing commands (`git for-each-ref`, `git log`,
   `git interpret-trailers`) without spawning additional processes.

4. **Simple over clever**: Prefer straightforward data models over
   mathematically optimal but complex ones. Three-way set merge over
   CRDTs. Last-writer-wins over Lamport clocks.

5. **Format over tool**: This specification defines a data format, not a
   tool. Any implementation that produces conforming refs and commits is
   a valid implementation.

---

## 2. Ref Namespace

Issues are stored under the `refs/issues/` namespace:

```
refs/issues/<uuid>
```

Where `<uuid>` is a full UUID version 4 (RFC 4122), lowercase,
hyphenated. Example:

```
refs/issues/a7f3b2c1-4e5d-4a8b-9c1e-2f3a4b5c6d7e
```

### 2.1 Display Identifiers

For human interaction, implementations SHOULD support abbreviated
identifiers using the first 7 characters of the UUID (before the first
hyphen). Implementations MUST expand abbreviated identifiers
unambiguously, prompting the user if multiple issues match a prefix.

Example: `a7f3b2c` refers to the issue above.

### 2.2 No Counter File

There is no `next-id` file, no sequential counter, and no coordination
mechanism. UUIDs are generated independently on each clone. This is the
only identity scheme that guarantees zero collisions in a distributed
system without coordination.

---

## 3. Issue Structure

Each issue is a chain of one or more commits pointed to by its ref.
The ref always points to the latest commit in the chain (the issue HEAD).

```
refs/issues/<uuid>
    |
    v
  [commit N]  <-- issue HEAD (latest state)
    |
  [commit N-1]
    |
   ...
    |
  [commit 1]  <-- root commit (issue creation)
```

### 3.1 Tree Object

All issue commits use the **empty tree** (`4b825dc642cb6eb9a060e54bf899d15006578022`).
Issues carry no file content; all data is in the commit message.

Implementations MUST use the empty tree. This ensures:
- No disk space wasted on tree objects
- Clear semantic distinction from code commits
- Compatibility with bare repositories

### 3.2 Commit Authorship

The commit author and committer fields carry the identity of the person
who created the issue or comment. Implementations SHOULD use the same
author identity as configured for regular code commits (`user.name` and
`user.email`).

---

## 4. Commit Message Format

Issue commits follow Git's standard commit message convention with
trailers:

```
<subject line>
                          <-- blank line
<body>
                          <-- blank line
<trailer-key>: <trailer-value>
<trailer-key>: <trailer-value>
...
```

### 4.1 Root Commit (Issue Creation)

The root commit (first commit in the chain, with no parent) defines the
issue:

```
<title>

<description>

State: open
Labels: <comma-separated labels>
Assignee: <email>
Format-Version: 1
```

**Required fields**:
- Subject line: The issue title (max 72 characters recommended)
- `State:` trailer: MUST be `open`
- `Format-Version:` trailer: MUST be `1`

**Optional fields**:
- Body: Detailed description of the issue
- `Labels:` trailer: Comma-separated list of labels
- `Assignee:` trailer: Email address of the assignee
- `Priority:` trailer: `low`, `medium`, `high`, or `critical`
- `Milestone:` trailer: Milestone name

**Example**:
```
Fix login crash with special characters

The login page crashes when the user enters special characters
in the password field. Steps to reproduce:
1. Go to login page
2. Enter "pa$$w0rd" as password
3. Click submit

State: open
Labels: bug, auth
Priority: high
Format-Version: 1
```

### 4.2 Comment Commit

A comment commit has the previous issue HEAD as its parent:

```
<comment summary>

<comment body>
```

Comment commits carry no trailers unless they also change issue state
(see Section 4.4). The subject line is a short summary; the body
contains the full comment text.

**Example**:
```
I can reproduce this on Firefox too

Tested on Firefox 120 and Chrome 119. Both crash with the same
error. The issue is in the password sanitizer function at
src/auth/sanitize.js:42.
```

### 4.3 State Change Commit

A state change commit modifies issue metadata:

```
<description of change>

State: closed
Fixed-By: <commit-sha>
```

**Recognized state values**: `open`, `closed`

Implementations MAY support additional states but MUST recognize
`open` and `closed`.

**Optional trailers for state changes**:
- `Fixed-By:` -- SHA of the commit that fixes the issue
- `Release:` -- Version in which the fix ships
- `Reason:` -- Reason for closing (e.g., `duplicate`, `wontfix`,
  `invalid`, `completed`)

**Example**:
```
Close issue -- fix deployed

The fix in commit abc123 handles special characters properly.
Verified in staging environment.

State: closed
Fixed-By: abc123def456789
Release: v2.1.0
Reason: completed
```

### 4.4 Combined Comment and State Change

A single commit MAY contain both a comment and a state change. This
is achieved by including trailers in a comment commit:

```
Fix deployed, closing

The fix in commit abc123 handles special characters properly.

State: closed
Fixed-By: abc123def456789
```

### 4.5 Custom Trailers

Implementations MAY use custom trailers prefixed with `X-`:

```
X-Severity: critical
X-Component: auth
X-Upstream-Bug: https://bugs.example.com/123
```

Custom trailers MUST NOT conflict with standard trailer names defined
in this specification.

### 4.6 Cross-References

To link a code commit to an issue, use the `Fixes-Issue:` trailer in
the code commit message:

```
Fix password sanitizer for special chars

The sanitizer was not escaping $ and other regex metacharacters.

Fixes-Issue: a7f3b2c
```

This is a trailer in a regular code commit (on a code branch), not in
an issue commit. Implementations SHOULD recognize these trailers and
display cross-references when showing issues.

---

## 5. State Computation

The current state of an issue is determined by walking the commit chain
from HEAD backward and taking the value of the `State:` trailer from
the **most recent commit that contains one**.

```sh
git log --format='%(trailers:key=State,valueonly)' refs/issues/<uuid> \
  | grep -m1 .
```

If no commit in the chain contains a `State:` trailer, the issue is
malformed. Implementations SHOULD treat such issues as `open` and
SHOULD warn the user.

### 5.1 Field Computation

Other fields follow similar rules:

| Field | Computation | Source |
|-------|------------|--------|
| Title | Subject line of root commit | Root commit only |
| Description | Body of root commit | Root commit only |
| State | Most recent `State:` trailer | Any commit |
| Labels | See Section 6 (merge rules) | Most recent `Labels:` trailer |
| Assignee | Most recent `Assignee:` trailer | Any commit |
| Priority | Most recent `Priority:` trailer | Any commit |
| Milestone | Most recent `Milestone:` trailer | Any commit |
| Comments | All non-root commits | Ordered by commit date |

### 5.2 Efficient Listing

A conforming implementation can list all issues with a single command:

```sh
git for-each-ref \
  --format='%(refname:short) %(contents:subject) %(trailers:key=State,valueonly)' \
  refs/issues/
```

This requires zero subprocess spawning and works efficiently for
thousands of issues.

---

## 6. Merge Rules

When two clones of a repository independently modify issues and then
synchronize (via `git fetch` + ref update), conflicts may arise.
The following rules define deterministic resolution:

### 6.1 Comments (Append-Only)

Comments are individual commits. Both sides' commits are included in the
merged chain, ordered by author timestamp. Conflicts are impossible
because each comment is a distinct commit object.

When merging divergent issue branches, create a merge commit combining
both chains. All comments from both sides are preserved.

### 6.2 State (Last-Writer-Wins)

If both sides changed the state, the commit with the later author
timestamp wins. If timestamps are equal, the commit with the
lexicographically greater SHA wins.

### 6.3 Labels (Three-Way Set Merge)

Labels use three-way set merge relative to the merge base:

1. Compute the label set at the merge base (ancestor)
2. Compute additions and removals for each side:
   - `added_A = labels_A - ancestor`
   - `removed_A = ancestor - labels_A`
   - (same for side B)
3. Result = `ancestor + added_A + added_B - removed_A - removed_B`
4. Tie-breaking: if one side added a label and the other removed it,
   the addition wins (bias toward keeping data)

### 6.4 Scalar Fields (Last-Writer-Wins)

For `Assignee:`, `Priority:`, `Milestone:`, and other scalar fields:
the commit with the later author timestamp wins. Equal timestamps are
broken by lexicographically greater SHA.

### 6.5 Title and Description

Title and description are set only in the root commit and are immutable.
If title changes are needed, implementations SHOULD use a `Title:`
trailer in a subsequent commit to override the original subject line.
The most recent `Title:` trailer wins (LWW).

### 6.6 Conflict Representation

If a merge produces a conflict that cannot be resolved automatically
(e.g., both sides changed the title to different values):

1. Create a merge commit with a `Conflict:` trailer listing the
   conflicting fields
2. The issue gets a `conflict` pseudo-label until resolved
3. Implementations SHOULD provide a `git issue resolve` command to
   allow the user to pick a resolution

---

## 7. Transport

Issues travel via standard Git transport. No custom protocol is needed.

### 7.1 Fetching Issues

```sh
git fetch origin 'refs/issues/*:refs/issues/*'
```

### 7.2 Pushing Issues

```sh
git push origin 'refs/issues/*'
```

### 7.3 Cloning with Issues

By default, `git clone` does NOT fetch `refs/issues/*`. To include
issues in a clone, configure the fetch refspec:

```sh
git config --add remote.origin.fetch '+refs/issues/*:refs/issues/*'
git fetch origin
```

Implementations SHOULD configure this refspec automatically when
initialized in a repository.

### 7.4 Shallow and Partial Clones

Issues are compatible with shallow clones. A shallow fetch of
`refs/issues/*` with `--depth=1` provides the current state of all
issues without full history. This is useful for large repositories
where full issue history is not needed locally.

---

## 8. Bridge Protocol

External issue trackers (GitHub, GitLab, Jira) can be bridged via
provider plugins. A bridge plugin is a separate executable named
`git-issue-remote-<provider>` that speaks a line-oriented text protocol
on stdin/stdout.

### 8.1 Capabilities

```
< capabilities
> list
> fetch
> push
> import-all
>
```

### 8.2 List

```
< list [--state=open|closed|all]
> <uuid-prefix> <state> <title>
> <uuid-prefix> <state> <title>
>
```

### 8.3 Fetch

```
< fetch <remote-id>
> uuid: <uuid>
> title: <title>
> state: <state>
> labels: <comma-separated>
> author: <name> <email>
> date: <ISO-8601>
> body:
> <body text, dot-stuffed>
> .
> comment:
> author: <name> <email>
> date: <ISO-8601>
> <comment text, dot-stuffed>
> .
>
```

### 8.4 Push

```
< push <uuid>
> ok <remote-id>
```

or

```
> error <message>
```

### 8.5 Import All

```
< import-all
> (same as multiple fetch responses)
```

The protocol uses **line-oriented text, NOT JSON**. This eliminates
the JSON injection class of bugs and allows simple shell-based
implementations.

---

## 9. Provider Mapping

When issues are imported from external providers, the source is
recorded via a `Provider-ID:` trailer:

```
Provider-ID: github:owner/repo#42
```

Format: `<provider>:<identifier>`

This enables:
- Round-trip import/export without duplication
- Cross-reference between local and remote issue IDs
- Detecting already-imported issues during subsequent imports

---

## 10. Compatibility Notes

### 10.1 Relationship to git-notes

This format does NOT use `git notes`. While `git notes` can attach
metadata to objects, notes are mutable (violating append-only semantics)
and do not support the commit-chain model needed for issue history.

### 10.2 Relationship to git-bug

This format is intentionally simpler than git-bug's operation-based
CRDT model. git-bug stores JSON blobs in git objects with Lamport
clocks. This format stores human-readable commit messages with standard
Git trailers. The two formats are not interoperable, but a bridge
between them is straightforward.

### 10.3 Relationship to Fossil

Fossil's ticket system uses immutable artifacts in a G-Set CRDT,
materialized into SQLite tables. This format achieves similar
properties (append-only commits, deterministic state computation)
using Git's native object model instead of SQLite.

### 10.4 Reftable Compatibility

This format uses proper Git refs (`refs/issues/*`) and is fully
compatible with the reftable backend. No plain files outside the
ref system are used.

---

## 11. Security Considerations

### 11.1 Trailer Injection

Implementations MUST validate that user-supplied values for trailer
fields do not contain newline characters. A newline in a trailer value
would inject arbitrary trailers.

### 11.2 Title Injection

Implementations MUST validate that issue titles do not contain newline
characters, as this would corrupt the commit message format.

### 11.3 Command Injection

Implementations MUST NOT pass user-supplied values through shell
expansion. Use `printf '%s'` instead of `echo` for user content.
Use `--` end-of-options markers in all git commands that accept
user-supplied arguments.

---

## 12. Future Extensions

The following features are deferred to Format-Version 2:

- **Binary attachments**: Store as blobs in the issue commit's tree
  object (instead of using the empty tree)
- **Reactions**: Emoji reactions as a `Reaction:` trailer
- **Templates**: Issue templates as blobs in `refs/issues/templates/`
- **Access control**: Per-issue access control lists
- **Live sync**: Bidirectional real-time synchronization with external
  providers

Extensions MUST increment the `Format-Version:` trailer. Implementations
MUST ignore trailers they do not recognize. Implementations MUST NOT
reject issues with a `Format-Version:` higher than they support; they
SHOULD process what they understand and warn about unrecognized fields.

---

## Acknowledgments

This specification was inspired by:
- Linus Torvalds's 2007 vision of "a git for bugs"
- D. Richard Hipp's Fossil ticket system
- Michael Mure's git-bug CRDT data model
- Julian Ganz and Matthias Beyer's git-dit commit-based approach
- Google's git-appraise `refs/notes/devtools/` architecture
- Diomidis Spinellis's git-issue pragmatic shell implementation

---

## References

- [RFC 4122 - UUID](https://tools.ietf.org/html/rfc4122)
- [gitformat-trailers(5)](https://git-scm.com/docs/git-interpret-trailers)
- [gitformat-pack(5)](https://git-scm.com/docs/gitformat-pack)
- [Linus Torvalds on Bug Tracking (2007)](https://yarchive.net/comp/linux/bug_tracking.html)
- [Fossil Ticket System](https://fossil-scm.org/home/doc/trunk/www/tickets.wiki)
- [git-bug Data Model](https://github.com/git-bug/git-bug/blob/master/doc/model.md)
