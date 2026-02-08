#!/bin/sh
#
# run-all.sh - Run the complete performance test suite
#
# Usage: run-all.sh [options]
#   -s <scale>    Scale: small (100), medium (500), large (1000), xl (2000)
#   -o <dir>      Output directory for results (default: /tmp/git-issue-perf-results)
#
set -e

SCALE="medium"
RESULTS_DIR="/tmp/git-issue-perf-results"

while test $# -gt 0
do
	case "$1" in
		-s) SCALE="$2"; shift 2 ;;
		-o) RESULTS_DIR="$2"; shift 2 ;;
		-h|--help)
			sed -n '3,6s/^# //p' "$0"
			exit 0
			;;
		*) echo "error: unknown option '$1'" >&2; exit 1 ;;
	esac
done

case "$SCALE" in
	small)  N=100;  MERGE_SHARED=50;  MERGE_NEW=10;  MERGE_DIV=20;  IMPORT_N=100 ;;
	medium) N=500;  MERGE_SHARED=200; MERGE_NEW=30;  MERGE_DIV=50;  IMPORT_N=500 ;;
	large)  N=1000; MERGE_SHARED=200; MERGE_NEW=50;  MERGE_DIV=50;  IMPORT_N=1000 ;;
	xl)     N=2000; MERGE_SHARED=500; MERGE_NEW=100; MERGE_DIV=100; IMPORT_N=2000 ;;
	*)      echo "error: scale must be small, medium, large, or xl" >&2; exit 1 ;;
esac

PERF_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$PERF_DIR/../../bin" && pwd)"
export PATH="$BIN_DIR:$PATH"

REPO_DIR="/tmp/git-issue-perf-repo"
MERGE_DIR="/tmp/git-issue-perf-merge"
MOCK_DIR="/tmp/git-issue-perf-mock"

mkdir -p "$RESULTS_DIR"

printf '==========================================================\n'
printf ' git-issue Performance Test Suite\n'
printf ' Scale: %s (%d issues)\n' "$SCALE" "$N"
printf ' Date:  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
printf '==========================================================\n\n'

# --- Phase 1: Generate scale repo ---
printf '>>> Phase 1: Generating scale repo (%d issues)...\n' "$N"
phase1_start="$(date +%s)"
sh "$PERF_DIR/generate-scale-repo.sh" -n "$N" -c 10 -d "$REPO_DIR" -q
phase1_elapsed=$(($(date +%s) - phase1_start))
printf 'Phase 1 complete in %ds\n\n' "$phase1_elapsed"

# --- Phase 2: Benchmark core commands ---
printf '>>> Phase 2: Benchmarking core commands...\n'
phase2_start="$(date +%s)"
sh "$PERF_DIR/benchmark.sh" -d "$REPO_DIR" -o "$RESULTS_DIR/benchmark-${SCALE}.tsv" -t "$SCALE"
phase2_elapsed=$(($(date +%s) - phase2_start))
printf 'Phase 2 complete in %ds\n\n' "$phase2_elapsed"

# --- Phase 3: Merge scenario ---
printf '>>> Phase 3: Generating merge scenario (%d shared, %d new/side, %d diverged)...\n' \
	"$MERGE_SHARED" "$MERGE_NEW" "$MERGE_DIV"
phase3_start="$(date +%s)"
sh "$PERF_DIR/generate-merge-scenario.sh" \
	-n "$MERGE_SHARED" -N "$MERGE_NEW" -D "$MERGE_DIV" -d "$MERGE_DIR"

printf '\nBenchmarking merge...\n'

cd "$MERGE_DIR/repo-b"
git remote add repo-a "$MERGE_DIR/repo-a" 2>/dev/null || true

# Warm up fetch
git fetch repo-a "+refs/issues/*:refs/remotes/repo-a/issues/*" 2>/dev/null

merge_header="scale\tshared\tnew\tdiverged\tcommand\treal_sec"
printf '%s\n' "$merge_header" > "$RESULTS_DIR/merge-${SCALE}.tsv"

# Benchmark merge --check
_start="$(python3 -c 'import time; print(f"{time.time():.3f}")')"
git issue merge repo-a --check --no-fetch > /dev/null 2>&1 || true
_end="$(python3 -c 'import time; print(f"{time.time():.3f}")')"
_real="$(echo "$_start $_end" | awk '{printf "%.3f", $2 - $1}')"
printf '%s\t%d\t%d\t%d\tmerge --check\t%s\n' \
	"$SCALE" "$MERGE_SHARED" "$MERGE_NEW" "$MERGE_DIV" "$_real" \
	>> "$RESULTS_DIR/merge-${SCALE}.tsv"
printf 'merge --check: %ss\n' "$_real"

# Re-fetch for actual merge (check consumed the staging refs)
git fetch repo-a "+refs/issues/*:refs/remotes/repo-a/issues/*" 2>/dev/null

_start="$(python3 -c 'import time; print(f"{time.time():.3f}")')"
git issue merge repo-a --no-fetch > /dev/null 2>&1 || true
_end="$(python3 -c 'import time; print(f"{time.time():.3f}")')"
_real="$(echo "$_start $_end" | awk '{printf "%.3f", $2 - $1}')"
printf '%s\t%d\t%d\t%d\tmerge\t%s\n' \
	"$SCALE" "$MERGE_SHARED" "$MERGE_NEW" "$MERGE_DIV" "$_real" \
	>> "$RESULTS_DIR/merge-${SCALE}.tsv"
printf 'merge (full): %ss\n' "$_real"

phase3_elapsed=$(($(date +%s) - phase3_start))
printf 'Phase 3 complete in %ds\n\n' "$phase3_elapsed"

# --- Phase 4: Mock GitHub import ---
printf '>>> Phase 4: Mock GitHub import (%d issues)...\n' "$IMPORT_N"
phase4_start="$(date +%s)"
sh "$PERF_DIR/generate-mock-gh.sh" -n "$IMPORT_N" -c 5 -d "$MOCK_DIR"

# Create a fresh repo for import
IMPORT_REPO="/tmp/git-issue-perf-import"
rm -rf "$IMPORT_REPO"
mkdir -p "$IMPORT_REPO"
cd "$IMPORT_REPO"
git init -q
git commit --allow-empty -m "init" -q

# Prepend mock gh to PATH
export PATH="$MOCK_DIR/bin:$BIN_DIR:$PATH"

import_header="scale\tissues\tcommand\treal_sec"
printf '%s\n' "$import_header" > "$RESULTS_DIR/import-${SCALE}.tsv"

_start="$(python3 -c 'import time; print(f"{time.time():.3f}")')"
git issue import github:testowner/testrepo --state all > /dev/null 2>&1 || true
_end="$(python3 -c 'import time; print(f"{time.time():.3f}")')"
_real="$(echo "$_start $_end" | awk '{printf "%.3f", $2 - $1}')"

imported_count="$(git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
printf '%s\t%d\timport\t%s\n' "$SCALE" "$IMPORT_N" "$_real" \
	>> "$RESULTS_DIR/import-${SCALE}.tsv"
printf 'Import: %d issues in %ss\n' "$imported_count" "$_real"

# Benchmark re-import (idempotency check)
_start="$(python3 -c 'import time; print(f"{time.time():.3f}")')"
git issue import github:testowner/testrepo --state all > /dev/null 2>&1 || true
_end="$(python3 -c 'import time; print(f"{time.time():.3f}")')"
_real="$(echo "$_start $_end" | awk '{printf "%.3f", $2 - $1}')"
printf '%s\t%d\tre-import (idempotent)\t%s\n' "$SCALE" "$IMPORT_N" "$_real" \
	>> "$RESULTS_DIR/import-${SCALE}.tsv"
printf 'Re-import (idempotent): %ss\n' "$_real"

phase4_elapsed=$(($(date +%s) - phase4_start))
printf 'Phase 4 complete in %ds\n\n' "$phase4_elapsed"

# --- Report ---
total_elapsed=$((phase1_elapsed + phase2_elapsed + phase3_elapsed + phase4_elapsed))

printf '==========================================================\n'
printf ' Performance Test Complete\n'
printf '==========================================================\n'
printf ' Scale:        %s (%d issues)\n' "$SCALE" "$N"
printf ' Total time:   %ds\n' "$total_elapsed"
printf ' Results dir:  %s\n' "$RESULTS_DIR"
printf ' Files:\n'
printf '   %s/benchmark-%s.tsv\n' "$RESULTS_DIR" "$SCALE"
printf '   %s/merge-%s.tsv\n' "$RESULTS_DIR" "$SCALE"
printf '   %s/import-%s.tsv\n' "$RESULTS_DIR" "$SCALE"
printf '==========================================================\n'

# --- Quick summary table ---
printf '\n--- Quick Summary ---\n'
if test -f "$RESULTS_DIR/benchmark-${SCALE}.tsv"
then
	printf '\nCore commands (avg of 3 runs):\n'
	tail -n +2 "$RESULTS_DIR/benchmark-${SCALE}.tsv" | while IFS='	' read -r _tag _n _cmd _real _user _sys
	do
		printf '  %-40s %6ss real  %6ss user  %6ss sys\n' "$_cmd" "$_real" "$_user" "$_sys"
	done
fi

if test -f "$RESULTS_DIR/merge-${SCALE}.tsv"
then
	printf '\nMerge (%d shared, %d new, %d diverged):\n' "$MERGE_SHARED" "$MERGE_NEW" "$MERGE_DIV"
	tail -n +2 "$RESULTS_DIR/merge-${SCALE}.tsv" | while IFS='	' read -r _s _sh _n _d _cmd _real
	do
		printf '  %-40s %6ss\n' "$_cmd" "$_real"
	done
fi

if test -f "$RESULTS_DIR/import-${SCALE}.tsv"
then
	printf '\nImport (mock GitHub, %d issues):\n' "$IMPORT_N"
	tail -n +2 "$RESULTS_DIR/import-${SCALE}.tsv" | while IFS='	' read -r _s _n _cmd _real
	do
		printf '  %-40s %6ss\n' "$_cmd" "$_real"
	done
fi

# --- Cleanup temp repos ---
printf '\nCleaning up temp repos...\n'
rm -rf "$REPO_DIR" "$MERGE_DIR" "$MOCK_DIR" "$IMPORT_REPO"
printf 'Done.\n'
