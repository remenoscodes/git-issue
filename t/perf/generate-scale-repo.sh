#!/bin/sh
#
# generate-scale-repo.sh - Generate a git-issue repo with thousands of issues
#
# Usage: generate-scale-repo.sh [options]
#   -n <count>    Number of issues to create (default: 1000)
#   -c <max>      Max comments per issue (random 0..max, default: 10)
#   -d <dir>      Output directory (default: /tmp/git-issue-perf-repo)
#   -s <seed>     Random seed for reproducibility (default: 42)
#   -q            Quiet mode (only show progress every 100 issues)
#
set -e

NUM_ISSUES=1000
MAX_COMMENTS=10
REPO_DIR="/tmp/git-issue-perf-repo"
SEED=42
QUIET=0

while test $# -gt 0
do
	case "$1" in
		-n) NUM_ISSUES="$2"; shift 2 ;;
		-c) MAX_COMMENTS="$2"; shift 2 ;;
		-d) REPO_DIR="$2"; shift 2 ;;
		-s) SEED="$2"; shift 2 ;;
		-q) QUIET=1; shift ;;
		-h|--help)
			sed -n '3,9s/^# //p' "$0"
			exit 0
			;;
		*) echo "error: unknown option '$1'" >&2; exit 1 ;;
	esac
done

BIN_DIR="$(cd "$(dirname "$0")/../../bin" && pwd)"

# Deterministic pseudo-random using awk
# Returns number 0..max-1
rand() {
	SEED=$((SEED * 1103515245 + 12345))
	SEED=$((SEED & 2147483647))
	echo $(( SEED % $1 ))
}

rand_item() {
	_count=$#
	_idx=$(rand "$_count")
	shift "$_idx"
	echo "$1"
}

LABELS="bug enhancement documentation performance security refactor test ci"
PRIORITIES="low medium high critical"
ASSIGNEES="alice@example.com bob@example.com carol@example.com dave@example.com eve@example.com"
MILESTONES="v1.0 v1.1 v2.0 backlog"
STATES="open open open open closed"  # 80% open, 20% closed

WORDS="fix add update remove implement refactor optimize test validate check handle parse process build deploy configure setup improve extend support"
NOUNS="module component service handler parser validator controller middleware endpoint cache database schema migration test fixture mock helper utility library"
ADJECTIVES="broken slow missing incorrect outdated incomplete invalid redundant inconsistent flaky"

rand_title() {
	_w1=$(rand_item $WORDS)
	_n1=$(rand_item $NOUNS)
	_a1=$(rand_item $ADJECTIVES)
	_idx=$(rand 3)
	case $_idx in
		0) echo "$_w1 $_a1 $_n1" ;;
		1) echo "$_w1 $_n1 for better performance" ;;
		2) echo "$_a1 $_n1 needs attention" ;;
	esac
}

rand_body() {
	_has_body=$(rand 3)  # 2/3 chance of having a body
	if test "$_has_body" -eq 0; then return; fi
	_lines=$(( $(rand 5) + 1 ))
	_i=0
	while test "$_i" -lt "$_lines"
	do
		_w1=$(rand_item $WORDS)
		_n1=$(rand_item $NOUNS)
		_n2=$(rand_item $NOUNS)
		echo "The $_n1 $_w1 needs to be updated because the $_n2 is affected."
		_i=$((_i + 1))
	done
}

rand_comment() {
	_w1=$(rand_item $WORDS)
	_n1=$(rand_item $NOUNS)
	_idx=$(rand 4)
	case $_idx in
		0) echo "I agree, the $_n1 should be changed." ;;
		1) echo "Can we $_w1 the $_n1 differently?" ;;
		2) echo "This is related to the $_n1 issue we saw last week." ;;
		3) echo "+1, this is blocking my work on the $_n1." ;;
	esac
}

# --- Setup repo ---
printf 'Generating scale repo: %d issues, max %d comments each\n' "$NUM_ISSUES" "$MAX_COMMENTS"
printf 'Output: %s\n' "$REPO_DIR"

rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init -q
git commit --allow-empty -m "init" -q

empty_tree="$(git hash-object -t tree /dev/null)"
tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

start_time="$(date +%s)"
i=0

while test "$i" -lt "$NUM_ISSUES"
do
	# Progress
	if test "$QUIET" -eq 0 || test $((i % 100)) -eq 0
	then
		if test $((i % 100)) -eq 0 && test "$i" -gt 0
		then
			elapsed=$(($(date +%s) - start_time))
			rate=$((i / (elapsed + 1)))
			printf '\r  [%d/%d] %d issues/sec' "$i" "$NUM_ISSUES" "$rate"
		fi
	fi

	# Generate UUID deterministically
	_a=$(printf '%08x' $((SEED * 7 + i * 13)))
	_b=$(printf '%04x' $((i % 65536)))
	_c=$(printf '%04x' $(( (SEED + i) % 65536 )))
	_d=$(printf '%04x' $(( (i * 3 + 1) % 65536 )))
	_e=$(printf '%012x' $((SEED * 11 + i * 17)))
	uuid="${_a}-${_b}-${_c}-${_d}-${_e}"

	title="$(rand_title)"
	body="$(rand_body)"
	state="$(rand_item $STATES)"
	num_labels=$(rand 4)
	num_comments=$(rand $((MAX_COMMENTS + 1)))

	# Build root commit message
	if test -n "$body"
	then
		printf '%s\n\n%s\n' "$title" "$body" > "$tmpfile"
	else
		printf '%s\n' "$title" > "$tmpfile"
	fi

	# Add trailers
	git interpret-trailers --in-place --trailer "State: open" "$tmpfile"

	# Random labels (0-3)
	if test "$num_labels" -gt 0
	then
		_label_list=""
		_li=0
		while test "$_li" -lt "$num_labels"
		do
			_l="$(rand_item $LABELS)"
			if test -z "$_label_list"
			then
				_label_list="$_l"
			else
				_label_list="$_label_list, $_l"
			fi
			_li=$((_li + 1))
		done
		git interpret-trailers --in-place --trailer "Labels: $_label_list" "$tmpfile"
	fi

	# Random priority (50% chance)
	if test $(rand 2) -eq 1
	then
		_p="$(rand_item $PRIORITIES)"
		git interpret-trailers --in-place --trailer "Priority: $_p" "$tmpfile"
	fi

	# Random assignee (40% chance)
	if test $(rand 5) -lt 2
	then
		_a="$(rand_item $ASSIGNEES)"
		git interpret-trailers --in-place --trailer "Assignee: $_a" "$tmpfile"
	fi

	# Random milestone (30% chance)
	if test $(rand 10) -lt 3
	then
		_m="$(rand_item $MILESTONES)"
		git interpret-trailers --in-place --trailer "Milestone: $_m" "$tmpfile"
	fi

	git interpret-trailers --in-place --trailer "Format-Version: 1" "$tmpfile"

	# Create root commit
	commit="$(git commit-tree -- "$empty_tree" < "$tmpfile")"
	git update-ref -- "refs/issues/$uuid" "$commit"

	parent="$commit"

	# Add comments
	_ci=0
	while test "$_ci" -lt "$num_comments"
	do
		_comment="$(rand_comment)"
		printf '%s\n' "$_comment" > "$tmpfile"
		new_commit="$(git commit-tree -p "$parent" -- "$empty_tree" < "$tmpfile")"
		parent="$new_commit"
		_ci=$((_ci + 1))
	done

	# Close if needed (add state-change commit)
	if test "$state" = "closed"
	then
		printf 'Close issue\n' > "$tmpfile"
		git interpret-trailers --in-place --trailer "State: closed" "$tmpfile"
		new_commit="$(git commit-tree -p "$parent" -- "$empty_tree" < "$tmpfile")"
		parent="$new_commit"
	fi

	# Update ref to final commit
	if test "$parent" != "$commit"
	then
		git update-ref -- "refs/issues/$uuid" "$parent" "$commit"
	fi

	i=$((i + 1))
done

elapsed=$(($(date +%s) - start_time))
total_refs="$(git for-each-ref refs/issues/ | wc -l | tr -d ' ')"
total_objects="$(git for-each-ref --format='%(refname)' refs/issues/ | while read -r ref; do git rev-list "$ref"; done | sort -u | wc -l | tr -d ' ')"
repo_size="$(du -sh .git | cut -f1)"

printf '\r\n\nScale repo generated:\n'
printf '  Issues:     %d\n' "$total_refs"
printf '  Objects:    %d\n' "$total_objects"
printf '  Repo size:  %s\n' "$repo_size"
printf '  Time:       %ds\n' "$elapsed"
printf '  Rate:       %d issues/sec\n' $((total_refs / (elapsed + 1)))
