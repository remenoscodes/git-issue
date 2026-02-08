#!/bin/sh
#
# generate-merge-scenario.sh - Generate two repos with divergent issues for merge testing
#
# Usage: generate-merge-scenario.sh [options]
#   -n <shared>    Number of shared issues (default: 200)
#   -N <new>       New issues per side (default: 50)
#   -D <diverged>  Diverged issues (default: 50)
#   -d <dir>       Base directory (default: /tmp/git-issue-perf-merge)
#
set -e

SHARED=200
NEW_PER_SIDE=50
DIVERGED=50
BASE_DIR="/tmp/git-issue-perf-merge"

while test $# -gt 0
do
	case "$1" in
		-n) SHARED="$2"; shift 2 ;;
		-N) NEW_PER_SIDE="$2"; shift 2 ;;
		-D) DIVERGED="$2"; shift 2 ;;
		-d) BASE_DIR="$2"; shift 2 ;;
		-h|--help)
			sed -n '3,8s/^# //p' "$0"
			exit 0
			;;
		*) echo "error: unknown option '$1'" >&2; exit 1 ;;
	esac
done

BIN_DIR="$(cd "$(dirname "$0")/../../bin" && pwd)"
export PATH="$BIN_DIR:$PATH"

REPO_A="$BASE_DIR/repo-a"
REPO_B="$BASE_DIR/repo-b"
SEED=12345

rand() {
	SEED=$((SEED * 1103515245 + 12345))
	SEED=$((SEED & 2147483647))
	echo $(( SEED % $1 ))
}

printf 'Generating merge scenario:\n'
printf '  Shared issues:  %d\n' "$SHARED"
printf '  New per side:   %d\n' "$NEW_PER_SIDE"
printf '  Diverged:       %d\n' "$DIVERGED"
printf '  Output:         %s\n\n' "$BASE_DIR"

rm -rf "$BASE_DIR"
mkdir -p "$BASE_DIR"

# --- Step 1: Create base repo with shared issues ---
printf 'Step 1: Creating base repo with %d shared issues...\n' "$SHARED"

mkdir -p "$REPO_A"
cd "$REPO_A"
git init -q
git commit --allow-empty -m "init" -q

empty_tree="$(git hash-object -t tree /dev/null)"
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

PRIORITIES="low medium high critical"
rand_item() {
	_count=$#
	_idx=$(rand "$_count")
	shift "$_idx"
	echo "$1"
}

i=0
while test "$i" -lt "$SHARED"
do
	_a=$(printf '%08x' $((SEED * 7 + i * 13)))
	_b=$(printf '%04x' $((i % 65536)))
	_c=$(printf '%04x' $(( (SEED + i) % 65536 )))
	_d=$(printf '%04x' $(( (i * 3 + 1) % 65536 )))
	_e=$(printf '%012x' $((SEED * 11 + i * 17)))
	uuid="${_a}-${_b}-${_c}-${_d}-${_e}"

	printf 'Issue #%d: shared base issue\n' "$i" > "$tmpfile"
	git interpret-trailers --in-place --trailer "State: open" "$tmpfile"
	git interpret-trailers --in-place --trailer "Priority: $(rand_item $PRIORITIES)" "$tmpfile"
	git interpret-trailers --in-place --trailer "Format-Version: 1" "$tmpfile"

	commit="$(git commit-tree -- "$empty_tree" < "$tmpfile")"
	git update-ref -- "refs/issues/$uuid" "$commit"

	# Add 1-3 comments
	parent="$commit"
	_nc=$(($(rand 3) + 1))
	_ci=0
	while test "$_ci" -lt "$_nc"
	do
		printf 'Comment %d on issue %d\n' "$_ci" "$i" > "$tmpfile"
		new_commit="$(git commit-tree -p "$parent" -- "$empty_tree" < "$tmpfile")"
		parent="$new_commit"
		_ci=$((_ci + 1))
	done
	git update-ref -- "refs/issues/$uuid" "$parent" "$commit"

	if test $((i % 50)) -eq 0 && test "$i" -gt 0
	then
		printf '  %d/%d shared issues created\n' "$i" "$SHARED"
	fi

	i=$((i + 1))
done

printf '  %d shared issues created\n' "$SHARED"

# --- Step 2: Clone to repo-b ---
printf 'Step 2: Cloning to repo-b...\n'
git clone -q "$REPO_A" "$REPO_B"
cd "$REPO_B"
# Copy issue refs (clone doesn't copy custom refs)
git fetch -q origin "+refs/issues/*:refs/issues/*"

# --- Step 3: Add unique issues to each side ---
printf 'Step 3: Adding %d new issues to each side...\n' "$NEW_PER_SIDE"

# New issues on repo-a
cd "$REPO_A"
i=0
while test "$i" -lt "$NEW_PER_SIDE"
do
	_a=$(printf '%08x' $((99999 * 7 + i * 13)))
	_b=$(printf '%04x' $((i % 65536)))
	_c="aaaa"
	_d=$(printf '%04x' $(( (i * 3 + 1) % 65536 )))
	_e=$(printf '%012x' $((99999 * 11 + i * 17)))
	uuid="${_a}-${_b}-${_c}-${_d}-${_e}"

	printf 'New issue on repo-a #%d\n' "$i" > "$tmpfile"
	git interpret-trailers --in-place --trailer "State: open" "$tmpfile"
	git interpret-trailers --in-place --trailer "Format-Version: 1" "$tmpfile"
	commit="$(git commit-tree -- "$empty_tree" < "$tmpfile")"
	git update-ref -- "refs/issues/$uuid" "$commit"
	i=$((i + 1))
done

# New issues on repo-b
cd "$REPO_B"
i=0
while test "$i" -lt "$NEW_PER_SIDE"
do
	_a=$(printf '%08x' $((88888 * 7 + i * 13)))
	_b=$(printf '%04x' $((i % 65536)))
	_c="bbbb"
	_d=$(printf '%04x' $(( (i * 3 + 1) % 65536 )))
	_e=$(printf '%012x' $((88888 * 11 + i * 17)))
	uuid="${_a}-${_b}-${_c}-${_d}-${_e}"

	printf 'New issue on repo-b #%d\n' "$i" > "$tmpfile"
	git interpret-trailers --in-place --trailer "State: open" "$tmpfile"
	git interpret-trailers --in-place --trailer "Format-Version: 1" "$tmpfile"
	commit="$(git commit-tree -- "$empty_tree" < "$tmpfile")"
	git update-ref -- "refs/issues/$uuid" "$commit"
	i=$((i + 1))
done

# --- Step 4: Create diverged issues ---
printf 'Step 4: Creating %d diverged issues...\n' "$DIVERGED"

# Get the first N shared issue UUIDs
shared_uuids="$(cd "$REPO_A" && git for-each-ref --format='%(refname:short)' refs/issues/ | head -"$DIVERGED")"

# Add different comments to same issues on each side
for short_ref in $shared_uuids
do
	uuid="${short_ref#issues/}"

	# Diverge on repo-a: add a comment + change priority
	cd "$REPO_A"
	head="$(git rev-parse "refs/issues/$uuid")"
	printf 'Comment from repo-a (divergent)\n' > "$tmpfile"
	git interpret-trailers --in-place --trailer "Priority: critical" "$tmpfile"
	new_commit="$(git commit-tree -p "$head" -- "$empty_tree" < "$tmpfile")"
	git update-ref -- "refs/issues/$uuid" "$new_commit" "$head"

	# Diverge on repo-b: add a different comment + change priority
	cd "$REPO_B"
	head="$(git rev-parse "refs/issues/$uuid")"
	printf 'Comment from repo-b (divergent)\n' > "$tmpfile"
	git interpret-trailers --in-place --trailer "Priority: low" "$tmpfile"
	new_commit="$(git commit-tree -p "$head" -- "$empty_tree" < "$tmpfile")"
	git update-ref -- "refs/issues/$uuid" "$new_commit" "$head"
done

printf '\nMerge scenario ready:\n'
printf '  Repo A: %s\n' "$REPO_A"
printf '  Repo B: %s\n' "$REPO_B"
a_count="$(cd "$REPO_A" && git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
b_count="$(cd "$REPO_B" && git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
printf '  Repo A issues: %d\n' "$a_count"
printf '  Repo B issues: %d\n' "$b_count"
printf '  Expected merge: %d new, ~%d up-to-date, %d diverged\n' \
	"$NEW_PER_SIDE" "$((SHARED - DIVERGED))" "$DIVERGED"
