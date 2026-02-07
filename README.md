# git-issue

Distributed issue tracking embedded in Git.

## The Problem

Your source code travels with `git clone`. Your issues don't.

Migrate from GitHub to GitLab? Your code comes with you. Your issues
stay behind, trapped in a proprietary API. Linus Torvalds called this
out in 2007:

> "A 'git for bugs', where you can track bugs locally and without a
> web interface."
>
> -- Linus Torvalds, [LKML 2007](https://yarchive.net/comp/linux/bug_tracking.html)

Nearly two decades later, this problem remains unsolved.

## The Solution

`git-issue` stores issues as Git commits under `refs/issues/`. No
external database. No JSON. No custom formats. Just commits, trailers,
and refs -- Git's own primitives.

```
$ git issue create "Fix login crash with special characters"
Created issue a7f3b2c

$ git issue ls
a7f3b2c [open]  Fix login crash with special characters
b3e9d1a [open]  Add dark mode support
c5f2a8e [closed] Update README with install instructions

$ git issue comment a7f3b2c -m "Reproduced on Firefox 120 and Chrome 119"
Added comment to a7f3b2c

$ git issue state a7f3b2c --close --fixed-by abc123
Closed issue a7f3b2c
```

Push issues to any remote. Fetch them back. They travel with the code:

```
$ git push origin 'refs/issues/*'
$ git fetch origin 'refs/issues/*:refs/issues/*'
```

## How It Works

Each issue is a chain of commits on its own ref:

```
refs/issues/a7f3b2c1-4e5d-...
    |
    v
  [Close issue]              State: closed
    |                        Fixed-By: abc123
  [Reproduced on Firefox]    (comment)
    |
  [Fix login crash...]       State: open
                             Labels: bug, auth
                             Format-Version: 1
```

The issue title is the commit subject line. The description is the
commit body. Metadata lives in standard Git trailers. Everything is
queryable with `git for-each-ref`:

```sh
git for-each-ref \
  --format='%(refname:short) %(contents:subject) %(trailers:key=State,valueonly)' \
  refs/issues/
```

Zero subprocess spawning. Works for 10,000+ issues.

## Install

```sh
# Clone and add to PATH
git clone https://github.com/remenoscodes/git-issue.git
export PATH="$PATH:$(pwd)/git-issue/bin"

# Or copy scripts to your git exec path
cp git-issue/bin/git-issue-* $(git --exec-path)/
```

## Commands

| Command | Description |
|---------|-------------|
| `git issue create <title>` | Create a new issue |
| `git issue ls` | List issues |
| `git issue show <id>` | Show issue details |
| `git issue comment <id>` | Add a comment |
| `git issue state <id>` | Change issue state |
| `git issue import` | Import from GitHub/GitLab |
| `git issue export` | Export to GitHub/GitLab |

## The Format Spec

The real deliverable is [ISSUE-FORMAT.md](ISSUE-FORMAT.md) -- a
standalone specification for storing issues in Git, independent of
this tool. Any implementation that produces conforming refs and commits
is a valid implementation.

If the Git community blesses this format, platforms like GitHub, GitLab,
and Forgejo can adopt native support for `refs/issues/*`, making issue
portability as natural as code portability.

## Design Decisions

- **UUIDs** (not sequential IDs) -- zero collision in distributed systems
- **Git trailers** (not JSON, not YAML) -- `interpret-trailers` compatible
- **Subject-line-as-title** -- `%(contents:subject)` works natively
- **Three-way set merge for labels** -- no CRDTs needed
- **Last-writer-wins for state** -- deterministic, simple
- **Import/export bridges** (not live sync) -- one hard problem at a time

See the [full design rationale](doc/design-rationale.md) for details.

## Prior Art

This project builds on lessons from 10+ previous attempts:

| Tool | Year | Status | Key Lesson |
|------|------|--------|-----------|
| Bugs Everywhere | 2005 | Dead | File-based storage creates merge conflicts |
| ticgit | 2008 | Dead | Creator (Scott Chacon) built GitHub instead |
| git-appraise | 2015 | Dead | `refs/notes/` model is elegant but needs ecosystem support |
| git-dit | 2016 | Dead | Commits + trailers works (validated our approach) |
| git-bug | 2018 | Active | CRDTs are overkill; missing format spec |
| Fossil | 2006 | Active | Proves CRDT-based append-only model works |

**What's different this time**: The format spec. No previous tool
produced a standalone, implementable specification. Every tool's
"format" was just whatever their code produced. `ISSUE-FORMAT.md` is
the deliverable that makes ecosystem adoption possible.

## License

GPL-2.0 -- same as Git itself.
