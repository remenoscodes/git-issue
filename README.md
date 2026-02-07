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

## Install

```sh
git clone https://github.com/remenoscodes/git-issue.git
cd git-issue

# Option 1: Install to ~/.local/bin (no sudo)
make install prefix=~/.local

# Option 2: Install system-wide
sudo make install

# Option 3: Just add to PATH
export PATH="$PATH:$(pwd)/bin"
```

Verify: `git issue version`

## Commands

| Command | Description |
|---------|-------------|
| `git issue create <title>` | Create a new issue |
| `git issue ls` | List issues |
| `git issue show <id>` | Show issue details and comments |
| `git issue comment <id>` | Add a comment |
| `git issue edit <id>` | Edit metadata (labels, assignee, priority, milestone) |
| `git issue state <id>` | Change issue state |
| `git issue import` | Import issues from GitHub |
| `git issue export` | Export issues to GitHub |
| `git issue sync` | Two-way sync (import + export) |
| `git issue merge <remote>` | Merge issues from a remote |
| `git issue fsck` | Validate issue data integrity |
| `git issue init` | Configure repo for issue tracking |

### Creating Issues

```sh
git issue create "Fix login crash" \
  -m "TypeError when clicking submit" \
  -l bug -l auth \
  -a alice@example.com \
  -p critical \
  --milestone v1.0
```

### Editing Issues

```sh
# Replace all labels
git issue edit a7f3b2c -l bug -l urgent

# Add/remove individual labels
git issue edit a7f3b2c --add-label security
git issue edit a7f3b2c --remove-label urgent

# Change assignee and priority
git issue edit a7f3b2c -a bob@example.com -p high

# Change title
git issue edit a7f3b2c -t "Fix login crash on special characters"
```

### Listing Issues

```sh
git issue ls                    # Open issues (default)
git issue ls --all              # All issues
git issue ls --state closed     # Closed issues
git issue ls -l bug             # Filter by label
git issue ls --format full      # Show labels, assignee, priority, milestone
git issue ls --format oneline   # Scripting-friendly (no brackets)
```

### GitHub Bridge

Import and export issues from/to GitHub. Requires [`gh`](https://cli.github.com/) and `jq`.

```sh
# Import all open issues from a GitHub repo
git issue import github:owner/repo

# Import all issues (open + closed)
git issue import github:owner/repo --state all

# Preview what would be imported
git issue import github:owner/repo --dry-run

# Export local issues to GitHub
git issue export github:owner/repo

# Two-way sync (import then export)
git issue sync github:owner/repo --state all
```

**How it works:**

- `import` fetches GitHub issues via `gh api`, creates local `refs/issues/` commits with full metadata (labels, assignee, milestone, comments, author)
- `export` creates GitHub issues from local issues, exports comments, syncs state
- A `Provider-ID` trailer tracks the mapping (e.g., `Provider-ID: github:owner/repo#42`) to prevent duplicates on re-import/re-export
- Re-importing skips already-imported issues; re-exporting syncs state changes

**Prerequisites:**

```sh
brew install gh jq       # macOS
gh auth login            # authenticate with GitHub
```

### Distributed Merge

When multiple people track the same issues, their ref chains can diverge.
`git issue merge` reconciles them:

```sh
# Fetch and merge issues from a remote
git issue merge origin

# Detect divergences without merging
git issue merge origin --check

# Skip fetch, use existing remote tracking refs
git issue merge origin --no-fetch
```

**Merge strategy:**

- New issues from remote are created locally
- If local is behind, fast-forward
- If diverged, create a merge commit with resolved metadata:
  - **Scalar fields** (state, assignee, priority, milestone): last-writer-wins by timestamp
  - **Labels**: three-way set merge (additions from both sides preserved, removals honored)
  - **Comments**: union (both sides' commits reachable via merge parents)

### Data Integrity

```sh
# Validate all issue refs
git issue fsck

# Quiet mode (only errors)
git issue fsck --quiet
```

Checks: UUID format, empty tree usage, required trailers (`State`, `Format-Version`), single root commit per issue.

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

## Running Tests

```sh
make test
```

132 tests: 76 core + 36 bridge + 20 merge/fsck.

## License

GPL-2.0 -- same as Git itself.
