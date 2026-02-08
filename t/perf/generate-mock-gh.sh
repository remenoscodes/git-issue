#!/bin/sh
#
# generate-mock-gh.sh - Generate mock GitHub API fixtures and a fake gh wrapper
#
# Usage: generate-mock-gh.sh [options]
#   -n <count>    Number of issues to generate (default: 1000)
#   -c <max>      Max comments per issue (default: 5)
#   -d <dir>      Output directory for fixtures (default: /tmp/git-issue-perf-mock)
#
set -e

NUM_ISSUES=1000
MAX_COMMENTS=5
MOCK_DIR="/tmp/git-issue-perf-mock"
SEED=7777

while test $# -gt 0
do
	case "$1" in
		-n) NUM_ISSUES="$2"; shift 2 ;;
		-c) MAX_COMMENTS="$2"; shift 2 ;;
		-d) MOCK_DIR="$2"; shift 2 ;;
		-h|--help)
			sed -n '3,7s/^# //p' "$0"
			exit 0
			;;
		*) echo "error: unknown option '$1'" >&2; exit 1 ;;
	esac
done

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

LABELS="bug enhancement documentation performance security"
USERS="alice bob carol dave eve frank"

printf 'Generating mock GitHub API data for %d issues (max %d comments each)\n' "$NUM_ISSUES" "$MAX_COMMENTS"

rm -rf "$MOCK_DIR"
mkdir -p "$MOCK_DIR/api/repos/testowner/testrepo/issues"
mkdir -p "$MOCK_DIR/api/users"
mkdir -p "$MOCK_DIR/bin"

# --- Generate issue list pages (100 per page) ---
page=1
issue_num=1
page_size=100

while test "$issue_num" -le "$NUM_ISSUES"
do
	page_file="$MOCK_DIR/api/repos/testowner/testrepo/issues/page-${page}.json"
	printf '[' > "$page_file"

	_page_count=0
	while test "$issue_num" -le "$NUM_ISSUES" && test "$_page_count" -lt "$page_size"
	do
		_state="open"
		if test $(rand 5) -eq 0; then _state="closed"; fi

		_user="$(rand_item $USERS)"
		_has_label=$(rand 2)
		_label="$(rand_item $LABELS)"

		if test "$_page_count" -gt 0; then printf ',' >> "$page_file"; fi

		cat >> "$page_file" <<ISSUE_EOF
{
  "number": $issue_num,
  "title": "Issue #$issue_num: $(rand_item fix add update remove) $(rand_item module service handler)",
  "body": "Description for issue $issue_num.\\nThis needs to be addressed.",
  "state": "$_state",
  "created_at": "2024-01-$(printf '%02d' $(( (issue_num % 28) + 1 )))T12:00:00Z",
  "closed_at": $(if test "$_state" = "closed"; then echo "\"2024-06-15T12:00:00Z\""; else echo "null"; fi),
  "updated_at": "2024-06-15T12:00:00Z",
  "user": {"login": "$_user"},
  "labels": [$(if test "$_has_label" -eq 1; then printf '{"name": "%s"}' "$_label"; fi)],
  "assignee": $(if test $(rand 3) -eq 0; then printf '{"login": "%s"}' "$(rand_item $USERS)"; else echo "null"; fi),
  "milestone": $(if test $(rand 4) -eq 0; then echo '{"title": "v1.0"}'; else echo "null"; fi),
  "pull_request": null
}
ISSUE_EOF
		issue_num=$((issue_num + 1))
		_page_count=$((_page_count + 1))
	done

	printf ']' >> "$page_file"
	page=$((page + 1))
done

total_pages=$((page - 1))

# --- Generate individual issue detail files ---
i=1
while test "$i" -le "$NUM_ISSUES"
do
	detail_file="$MOCK_DIR/api/repos/testowner/testrepo/issues/${i}.json"

	_state="open"
	# Reproduce same randomness — reset seed for this issue
	_user="$(rand_item $USERS)"

	cat > "$detail_file" <<DETAIL_EOF
{
  "number": $i,
  "title": "Issue #$i: detailed view",
  "body": "Full description for issue $i.\\nMultiple lines of context here.",
  "state": "open",
  "created_at": "2024-01-$(printf '%02d' $(( (i % 28) + 1 )))T12:00:00Z",
  "closed_at": null,
  "updated_at": "2024-06-15T12:00:00Z",
  "user": {"login": "$_user"},
  "labels": [],
  "assignee": null,
  "milestone": null
}
DETAIL_EOF

	# --- Generate comments ---
	_nc=$(rand $((MAX_COMMENTS + 1)))
	comments_file="$MOCK_DIR/api/repos/testowner/testrepo/issues/${i}/comments.json"
	mkdir -p "$MOCK_DIR/api/repos/testowner/testrepo/issues/${i}"

	printf '[' > "$comments_file"
	_ci=0
	while test "$_ci" -lt "$_nc"
	do
		_cuser="$(rand_item $USERS)"
		if test "$_ci" -gt 0; then printf ',' >> "$comments_file"; fi
		cat >> "$comments_file" <<COMMENT_EOF
{
  "body": "Comment $_ci on issue $i by $_cuser",
  "created_at": "2024-02-$(printf '%02d' $(( (_ci % 28) + 1 )))T12:00:00Z",
  "user": {"login": "$_cuser"}
}
COMMENT_EOF
		_ci=$((_ci + 1))
	done
	printf ']' >> "$comments_file"

	if test $((i % 200)) -eq 0
	then
		printf '  Generated fixtures for %d/%d issues\n' "$i" "$NUM_ISSUES"
	fi

	i=$((i + 1))
done

# --- Generate user fixtures ---
for _u in $USERS
do
	cat > "$MOCK_DIR/api/users/${_u}.json" <<USER_EOF
{
  "login": "$_u",
  "name": "$(echo "$_u" | sed 's/./\U&/') User",
  "email": "${_u}@example.com"
}
USER_EOF
done

# --- Generate mock gh script ---
cat > "$MOCK_DIR/bin/gh" <<'GH_SCRIPT'
#!/bin/sh
#
# Mock gh CLI that serves pre-generated JSON fixtures
#
MOCK_DIR="$(dirname "$0")/.."

case "$1" in
	auth)
		# Always succeed for auth status
		exit 0
		;;
	api)
		shift
		paginate=0
		method="GET"
		while test $# -gt 0
		do
			case "$1" in
				--paginate) paginate=1; shift ;;
				--method) method="$2"; shift 2 ;;
				*) break ;;
			esac
		done
		endpoint="$1"

		# Strip query parameters for file lookup
		path="${endpoint%%\?*}"

		if test "$paginate" -eq 1
		then
			# Serve all page files concatenated
			page=1
			first=1
			while true
			do
				page_file="$MOCK_DIR/api${path}/page-${page}.json"
				if ! test -f "$page_file"; then break; fi
				if test "$first" -eq 1
				then
					cat "$page_file"
					first=0
				else
					# Merge arrays: strip outer brackets and concatenate
					cat "$page_file"
				fi
				page=$((page + 1))
			done
		else
			# Check for direct file
			if test -f "$MOCK_DIR/api${path}.json"
			then
				cat "$MOCK_DIR/api${path}.json"
			elif test -f "$MOCK_DIR/api${path}"
			then
				cat "$MOCK_DIR/api${path}"
			else
				# Check for comments path pattern: /issues/N/comments
				comments_file="$MOCK_DIR/api${path}.json"
				if test -f "$comments_file"
				then
					cat "$comments_file"
				else
					echo "[]"
				fi
			fi
		fi
		;;
	*)
		echo "mock gh: unsupported command '$1'" >&2
		exit 1
		;;
esac
GH_SCRIPT

chmod +x "$MOCK_DIR/bin/gh"

total_size="$(du -sh "$MOCK_DIR" | cut -f1)"
printf '\nMock GitHub API generated:\n'
printf '  Issues:     %d\n' "$NUM_ISSUES"
printf '  Pages:      %d\n' "$total_pages"
printf '  Fixture dir: %s (%s)\n' "$MOCK_DIR" "$total_size"
printf '  Mock gh:    %s/bin/gh\n' "$MOCK_DIR"
printf '\nUsage:\n'
printf '  export PATH="%s/bin:$PATH"\n' "$MOCK_DIR"
printf '  git issue import github:testowner/testrepo\n'
