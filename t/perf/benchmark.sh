#!/bin/sh
#
# benchmark.sh - Benchmark git-issue commands against a scale repo
#
# Usage: benchmark.sh [options]
#   -d <dir>      Repo directory (default: /tmp/git-issue-perf-repo)
#   -o <file>     Output TSV file (default: stdout)
#   -t <tag>      Tag for this run (e.g., "baseline", "optimized")
#
set -e

REPO_DIR="/tmp/git-issue-perf-repo"
OUTPUT=""
TAG="baseline"

while test $# -gt 0
do
	case "$1" in
		-d) REPO_DIR="$2"; shift 2 ;;
		-o) OUTPUT="$2"; shift 2 ;;
		-t) TAG="$2"; shift 2 ;;
		-h|--help)
			sed -n '3,7s/^# //p' "$0"
			exit 0
			;;
		*) echo "error: unknown option '$1'" >&2; exit 1 ;;
	esac
done

BIN_DIR="$(cd "$(dirname "$0")/../../bin" && pwd)"
export PATH="$BIN_DIR:$PATH"

if ! test -d "$REPO_DIR/.git"
then
	echo "error: $REPO_DIR is not a git repo. Run generate-scale-repo.sh first." >&2
	exit 1
fi

cd "$REPO_DIR"

# Count issues for context
issue_count="$(git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
printf 'Benchmarking with %d issues (tag: %s)\n\n' "$issue_count" "$TAG"

# TSV header
if test -n "$OUTPUT"
then
	printf 'tag\tissues\tcommand\treal_sec\n' > "$OUTPUT"
fi
printf '%-45s %10s\n' "COMMAND" "TIME (avg 3)"
printf '%-45s %10s\n' "-------" "----------"

# Benchmark helper: runs command 3 times, reports average wall-clock time
bench() {
	_label="$1"
	shift

	_real_total=0
	_runs=3

	_r=0
	while test "$_r" -lt "$_runs"
	do
		_start="$(python3 -c 'import time; print(f"{time.time():.3f}")')"
		sh -c "$*" > /dev/null 2>&1 || true
		_end="$(python3 -c 'import time; print(f"{time.time():.3f}")')"
		_elapsed="$(echo "$_start $_end" | awk '{printf "%.3f", $2 - $1}')"
		_real_total="$(echo "$_real_total $_elapsed" | awk '{printf "%.3f", $1 + $2}')"
		_r=$((_r + 1))
	done

	_real_avg="$(echo "$_real_total $_runs" | awk '{printf "%.3f", $1 / $2}')"

	printf '%-45s %8ss\n' "$_label" "$_real_avg"
	if test -n "$OUTPUT"
	then
		printf '%s\t%d\t%s\t%s\n' "$TAG" "$issue_count" "$_label" "$_real_avg" >> "$OUTPUT"
	fi
}

printf '%s\n' '--- Listing ---'
bench "ls (open only)" "git issue ls"
bench "ls --all" "git issue ls --all"
bench "ls --all --sort priority" "git issue ls --all --sort priority"
bench "ls --all --sort updated" "git issue ls --all --sort updated"
bench "ls --assignee (filter)" "git issue ls --all --assignee alice@example.com"
bench "ls --priority critical (filter)" "git issue ls --all --priority critical"
bench "ls --label bug (filter)" "git issue ls --all --label bug"

printf '\n%s\n' '--- Search ---'
bench "search (common word)" "git issue search module"
bench "search (rare word)" "git issue search xyznotfound"
bench "search -i (case insensitive)" "git issue search -i MODULE"
bench "search --state open" "git issue search --state open module"

printf '\n%s\n' '--- Show ---'
# Find an issue with many comments
_heavy_id="$(git for-each-ref --format='%(refname)' refs/issues/ | head -1)"
_heavy_short="$(printf '%s' "${_heavy_id#refs/issues/}" | cut -c1-7)"
bench "show (single issue)" "git issue show $_heavy_short"

printf '\n%s\n' '--- Fsck ---'
bench "fsck" "git issue fsck"
bench "fsck --quiet" "git issue fsck --quiet"

printf '\n%s\n' '--- Merge (setup + execute) ---'
# Create a clone to merge from
_merge_remote="/tmp/git-issue-perf-merge-remote"
rm -rf "$_merge_remote"
git clone -q --bare "$REPO_DIR" "$_merge_remote" 2>/dev/null
git remote remove perf-remote 2>/dev/null || true
git remote add perf-remote "$_merge_remote"

bench "merge --check (no divergence)" "git issue merge perf-remote --check"
bench "merge (no divergence)" "git issue merge perf-remote"

# Clean up
git remote remove perf-remote 2>/dev/null || true
rm -rf "$_merge_remote"

printf '\n%s\n' '--- Summary ---'
printf 'Benchmark complete for %d issues\n' "$issue_count"
if test -n "$OUTPUT"
then
	printf 'Results saved to: %s\n' "$OUTPUT"
fi
