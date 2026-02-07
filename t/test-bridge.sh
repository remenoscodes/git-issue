#!/bin/sh
#
# Tests for git-issue import/export (GitHub bridge)
#
# Run: sh t/test-bridge.sh
#
# Uses a mock 'gh' script that returns fixture JSON based on API paths.
# Real 'jq' is used (not mocked).
#

set -e

# Colors (if terminal supports them)
if test -t 1
then
	RED='\033[0;31m'
	GREEN='\033[0;32m'
	YELLOW='\033[0;33m'
	NC='\033[0m'
else
	RED=''
	GREEN=''
	YELLOW=''
	NC=''
fi

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

BIN_DIR="$(cd "$(dirname "$0")/../bin" && pwd)"
FIXTURE_DIR="$(cd "$(dirname "$0")/fixtures" && pwd)"
TEST_DIR="$(mktemp -d)"

trap 'rm -rf "$TEST_DIR"' EXIT

pass() {
	TESTS_PASSED=$((TESTS_PASSED + 1))
	printf "${GREEN}  PASS${NC} %s\n" "$1"
}

fail() {
	TESTS_FAILED=$((TESTS_FAILED + 1))
	printf "${RED}  FAIL${NC} %s\n" "$1"
	if test -n "${2:-}"
	then
		printf "       %s\n" "$2"
	fi
}

run_test() {
	TESTS_RUN=$((TESTS_RUN + 1))
}

# Set up a fresh test repo with mock gh on PATH
setup_repo() {
	rm -rf "$TEST_DIR/repo"
	mkdir "$TEST_DIR/repo"
	cd "$TEST_DIR/repo"
	git init -q
	git commit --allow-empty -q -m "initial"

	# Create mock gh
	mkdir -p "$TEST_DIR/mock-bin"
	create_mock_gh
	chmod +x "$TEST_DIR/mock-bin/gh"

	export PATH="$TEST_DIR/mock-bin:$BIN_DIR:$PATH"
}

# Default mock gh that handles the standard import test case
create_mock_gh() {
	cat > "$TEST_DIR/mock-bin/gh" <<MOCKEOF
#!/bin/sh
# Mock gh CLI for testing

case "\$*" in
	"auth status")
		exit 0
		;;
	*"api --paginate /repos/testowner/testrepo/issues?"*"per_page=100")
		cat "$FIXTURE_DIR/issues-list.json"
		;;
	*"api /repos/testowner/testrepo/issues/1")
		cat "$FIXTURE_DIR/issue-1.json"
		;;
	*"api /repos/testowner/testrepo/issues/2")
		cat "$FIXTURE_DIR/issue-2.json"
		;;
	*"api --paginate /repos/testowner/testrepo/issues/1/comments"*)
		cat "$FIXTURE_DIR/issue-1-comments.json"
		;;
	*"api --paginate /repos/testowner/testrepo/issues/2/comments"*)
		cat "$FIXTURE_DIR/issue-2-comments.json"
		;;
	*"api /users/alice")
		cat "$FIXTURE_DIR/user-alice.json"
		;;
	*"api /users/bob")
		cat "$FIXTURE_DIR/user-bob.json"
		;;
	*"api /users/charlie")
		cat "$FIXTURE_DIR/user-charlie.json"
		;;
	*"--method POST"*"/comments"*)
		# Handle comment creation (export)
		echo '{"id": 999}'
		;;
	*"--method POST"*"/issues"*)
		# Handle issue creation (export)
		echo '{"number": 42, "html_url": "https://github.com/testowner/testrepo/issues/42"}'
		;;
	*"--method PATCH"*"/issues/"*)
		# Handle issue state update (export sync)
		echo '{}'
		;;
	*)
		echo "mock-gh: unhandled call: \$*" >&2
		exit 1
		;;
esac
MOCKEOF
}

printf "Running git-issue bridge tests...\n\n"

# ============================================================
# IMPORT TESTS
# ============================================================

# ============================================================
# TEST: import creates correct refs
# ============================================================
run_test
setup_repo
output="$(git issue import github:testowner/testrepo --state all 2>&1)"
ref_count="$(git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
if test "$ref_count" -eq 2
then
	pass "import creates refs for issues (filters out PRs)"
else
	fail "import creates refs for issues (filters out PRs)" "expected 2 refs, got $ref_count"
fi

# ============================================================
# TEST: imported issue has correct title
# ============================================================
run_test
# Find the issue with title "Login page crashes on submit"
found_title=0
for ref in $(git for-each-ref --format='%(refname)' refs/issues/)
do
	root="$(git rev-list --max-parents=0 "$ref")"
	subject="$(git log -1 --format='%s' "$root")"
	if test "$subject" = "Login page crashes on submit"
	then
		found_title=1
		issue1_ref="$ref"
		break
	fi
done
if test "$found_title" -eq 1
then
	pass "imported issue has correct title"
else
	fail "imported issue has correct title" "title not found"
fi

# ============================================================
# TEST: imported issue has Provider-ID trailer
# ============================================================
run_test
root="$(git rev-list --max-parents=0 "$issue1_ref")"
pid="$(git log -1 --format='%(trailers:key=Provider-ID,valueonly)' "$root" | sed '/^$/d')"
pid="$(printf '%s' "$pid" | sed 's/^[[:space:]]*//')"
if test "$pid" = "github:testowner/testrepo#1"
then
	pass "imported issue has correct Provider-ID trailer"
else
	fail "imported issue has correct Provider-ID trailer" "got: '$pid'"
fi

# ============================================================
# TEST: imported issue has Format-Version trailer
# ============================================================
run_test
fv="$(git log -1 --format='%(trailers:key=Format-Version,valueonly)' "$root" | sed '/^$/d')"
fv="$(printf '%s' "$fv" | sed 's/^[[:space:]]*//')"
if test "$fv" = "1"
then
	pass "imported issue has Format-Version: 1 trailer"
else
	fail "imported issue has Format-Version: 1 trailer" "got: '$fv'"
fi

# ============================================================
# TEST: imported issue has correct labels
# ============================================================
run_test
labels="$(git log -1 --format='%(trailers:key=Labels,valueonly)' "$root" | sed '/^$/d')"
labels="$(printf '%s' "$labels" | sed 's/^[[:space:]]*//')"
if test "$labels" = "bug, auth"
then
	pass "imported issue preserves labels"
else
	fail "imported issue preserves labels" "got: '$labels'"
fi

# ============================================================
# TEST: imported issue has correct assignee
# ============================================================
run_test
assignee="$(git log -1 --format='%(trailers:key=Assignee,valueonly)' "$root" | sed '/^$/d')"
assignee="$(printf '%s' "$assignee" | sed 's/^[[:space:]]*//')"
# bob has no email, so should use noreply
if test "$assignee" = "bob@users.noreply.github.com"
then
	pass "imported issue preserves assignee (noreply fallback)"
else
	fail "imported issue preserves assignee (noreply fallback)" "got: '$assignee'"
fi

# ============================================================
# TEST: imported issue has correct milestone
# ============================================================
run_test
ms="$(git log -1 --format='%(trailers:key=Milestone,valueonly)' "$root" | sed '/^$/d')"
ms="$(printf '%s' "$ms" | sed 's/^[[:space:]]*//')"
if test "$ms" = "v1.0"
then
	pass "imported issue preserves milestone"
else
	fail "imported issue preserves milestone" "got: '$ms'"
fi

# ============================================================
# TEST: imported issue has correct body
# ============================================================
run_test
body="$(git log -1 --format='%b' "$root" | sed '/^[A-Z][A-Za-z-]*: /d' | sed '/^$/d')"
case "$body" in
	*"TypeError"*"Steps to reproduce"*)
		pass "imported issue preserves body"
		;;
	*)
		fail "imported issue preserves body" "body missing expected content"
		;;
esac

# ============================================================
# TEST: imported issue has author from GitHub
# ============================================================
run_test
author_name="$(git log -1 --format='%an' "$root")"
author_email="$(git log -1 --format='%ae' "$root")"
if test "$author_name" = "Alice Smith" && test "$author_email" = "alice@example.com"
then
	pass "imported issue maps author correctly"
else
	fail "imported issue maps author correctly" "name='$author_name' email='$author_email'"
fi

# ============================================================
# TEST: imported issue has comments as child commits
# ============================================================
run_test
# Issue #1 has 2 comments + 0 state changes = root + 2 = 3 commits
total="$(git rev-list --count "$issue1_ref")"
if test "$total" -eq 3
then
	pass "imported comments create child commits (2 comments)"
else
	fail "imported comments create child commits (2 comments)" "expected 3 commits, got $total"
fi

# ============================================================
# TEST: comment content is preserved
# ============================================================
run_test
head_commit="$(git rev-parse "$issue1_ref")"
comment_subject="$(git log -1 --format='%s' "$head_commit")"
case "$comment_subject" in
	*"fix is in PR"*)
		pass "comment content is preserved"
		;;
	*)
		fail "comment content is preserved" "got: '$comment_subject'"
		;;
esac

# ============================================================
# TEST: closed issue has State: closed
# ============================================================
run_test
# Find issue #2 (closed)
for ref in $(git for-each-ref --format='%(refname)' refs/issues/)
do
	root="$(git rev-list --max-parents=0 "$ref")"
	subject="$(git log -1 --format='%s' "$root")"
	if test "$subject" = "Update README with install instructions"
	then
		issue2_ref="$ref"
		break
	fi
done
state="$(git log --format='%(trailers:key=State,valueonly)' "$issue2_ref" | sed '/^$/d' | head -1)"
state="$(printf '%s' "$state" | sed 's/^[[:space:]]*//')"
if test "$state" = "closed"
then
	pass "closed GitHub issue imported with State: closed"
else
	fail "closed GitHub issue imported with State: closed" "got: '$state'"
fi

# ============================================================
# TEST: closed issue has close commit
# ============================================================
run_test
# Issue #2: root + close commit = 2 (no comments)
total="$(git rev-list --count "$issue2_ref")"
if test "$total" -eq 2
then
	pass "closed issue has state-change commit"
else
	fail "closed issue has state-change commit" "expected 2 commits, got $total"
fi

# ============================================================
# TEST: idempotency - re-import skips already-imported
# ============================================================
run_test
output="$(git issue import github:testowner/testrepo --state all 2>&1)"
ref_count="$(git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
case "$output" in
	*"skipped"*)
		if test "$ref_count" -eq 2
		then
			pass "re-import skips already-imported issues (idempotent)"
		else
			fail "re-import skips already-imported issues (idempotent)" "ref count changed to $ref_count"
		fi
		;;
	*)
		fail "re-import skips already-imported issues (idempotent)" "output: $output"
		;;
esac

# ============================================================
# TEST: import with --state open filters correctly
# ============================================================
run_test
setup_repo
# Create a mock that only returns open issues when state=open
cat > "$TEST_DIR/mock-bin/gh" <<'MOCKEOF2'
#!/bin/sh
case "$*" in
	"auth status")
		exit 0
		;;
	*"state=open"*)
		printf '[{"number":1,"title":"Open one","state":"open","pull_request":null}]\n'
		;;
	*"api /repos/testowner/testrepo/issues/1")
		printf '{"number":1,"title":"Open one","body":"","state":"open","created_at":"2025-01-01T00:00:00Z","user":{"login":"dev"},"labels":[],"assignee":null,"milestone":null}\n'
		;;
	*"api --paginate /repos/testowner/testrepo/issues/1/comments"*)
		printf '[]\n'
		;;
	*"api /users/dev")
		printf '{"login":"dev","name":"Dev User","email":"dev@test.com"}\n'
		;;
	*)
		echo "mock-gh: unhandled: $*" >&2
		exit 1
		;;
esac
MOCKEOF2
chmod +x "$TEST_DIR/mock-bin/gh"
git issue import github:testowner/testrepo --state open >/dev/null 2>&1
ref_count="$(git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
if test "$ref_count" -eq 1
then
	pass "import --state open only imports open issues"
else
	fail "import --state open only imports open issues" "got $ref_count refs"
fi

# ============================================================
# TEST: import with --dry-run does not create refs
# ============================================================
run_test
setup_repo
create_mock_gh
chmod +x "$TEST_DIR/mock-bin/gh"
output="$(git issue import github:testowner/testrepo --state all --dry-run 2>&1)"
ref_count="$(git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
if test "$ref_count" -eq 0
then
	case "$output" in
		*"dry-run"*"Would import"*)
			pass "import --dry-run shows plan but creates no refs"
			;;
		*)
			fail "import --dry-run shows plan but creates no refs" "output: $output"
			;;
	esac
else
	fail "import --dry-run shows plan but creates no refs" "created $ref_count refs"
fi

# ============================================================
# TEST: import with empty body works
# ============================================================
run_test
setup_repo
cat > "$TEST_DIR/mock-bin/gh" <<'MOCKEOF3'
#!/bin/sh
case "$*" in
	"auth status") exit 0 ;;
	*"api --paginate /repos/"*"/issues?"*)
		printf '[{"number":1,"title":"No body issue","state":"open","pull_request":null}]\n'
		;;
	*"api /repos/"*"/issues/1")
		printf '{"number":1,"title":"No body issue","body":null,"state":"open","created_at":"2025-01-01T00:00:00Z","user":{"login":"dev"},"labels":[],"assignee":null,"milestone":null}\n'
		;;
	*"api --paginate /repos/"*"/issues/1/comments"*)
		printf '[]\n'
		;;
	*"api /users/dev")
		printf '{"login":"dev","name":"Dev","email":"dev@test.com"}\n'
		;;
	*) echo "mock-gh: unhandled: $*" >&2; exit 1 ;;
esac
MOCKEOF3
chmod +x "$TEST_DIR/mock-bin/gh"
git issue import github:testowner/testrepo >/dev/null 2>&1
ref_count="$(git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
if test "$ref_count" -eq 1
then
	pass "import with null/empty body works"
else
	fail "import with null/empty body works" "got $ref_count refs"
fi

# ============================================================
# TEST: import with invalid provider string fails
# ============================================================
run_test
setup_repo
if git issue import "invalid-provider" 2>/dev/null
then
	fail "import with invalid provider string fails" "should have failed"
else
	pass "import with invalid provider string fails"
fi

# ============================================================
# TEST: import outside git repo fails
# ============================================================
run_test
tmpdir="$(mktemp -d)"
cd "$tmpdir"
if git issue import github:testowner/testrepo 2>/dev/null
then
	fail "import outside git repo fails" "should have failed"
else
	pass "import outside git repo fails"
fi
rm -rf "$tmpdir"

# ============================================================
# TEST: import with missing gh fails
# ============================================================
run_test
setup_repo
# Remove mock gh from PATH temporarily
old_path="$PATH"
export PATH="$BIN_DIR:/usr/bin:/bin"
if git issue import github:testowner/testrepo 2>/dev/null
then
	fail "import with missing gh fails" "should have failed"
else
	pass "import with missing gh fails"
fi
export PATH="$old_path"

# ============================================================
# TEST: import uses empty tree for all commits
# ============================================================
run_test
setup_repo
create_mock_gh
chmod +x "$TEST_DIR/mock-bin/gh"
git issue import github:testowner/testrepo --state all >/dev/null 2>&1
empty_tree="$(git hash-object -t tree /dev/null)"
all_ok=1
for ref in $(git for-each-ref --format='%(refname)' refs/issues/)
do
	for commit in $(git rev-list "$ref")
	do
		tree="$(git log -1 --format='%T' "$commit")"
		if test "$tree" != "$empty_tree"
		then
			all_ok=0
			break
		fi
	done
done
if test "$all_ok" -eq 1
then
	pass "all imported commits use empty tree"
else
	fail "all imported commits use empty tree"
fi

# ============================================================
# TEST: imported issue ref uses UUID format
# ============================================================
run_test
all_uuid=1
for ref in $(git for-each-ref --format='%(refname)' refs/issues/)
do
	uuid="${ref#refs/issues/}"
	case "$uuid" in
		????????-????-????-????-????????????) ;;
		*) all_uuid=0 ;;
	esac
done
if test "$all_uuid" -eq 1
then
	pass "imported issues use UUID format for refs"
else
	fail "imported issues use UUID format for refs"
fi

# ============================================================
# EXPORT TESTS
# ============================================================

# ============================================================
# TEST: export creates GitHub issue and records Provider-ID
# ============================================================
run_test
setup_repo
create_mock_gh
chmod +x "$TEST_DIR/mock-bin/gh"
# Create a local issue
git issue create "Export test issue" -m "Test body" -l bug >/dev/null
output="$(git issue export github:testowner/testrepo 2>&1)"
case "$output" in
	*"Exported"*"#42"*)
		pass "export creates GitHub issue and reports number"
		;;
	*)
		fail "export creates GitHub issue and reports number" "output: $output"
		;;
esac

# ============================================================
# TEST: export records Provider-ID in local commit chain
# ============================================================
run_test
ref="$(git for-each-ref --format='%(refname)' refs/issues/ | head -1)"
pid="$(git log --format='%(trailers:key=Provider-ID,valueonly)' "$ref" | sed '/^$/d' | sed 's/^[[:space:]]*//' | head -1)"
if test "$pid" = "github:testowner/testrepo#42"
then
	pass "export records Provider-ID in commit chain"
else
	fail "export records Provider-ID in commit chain" "got: '$pid'"
fi

# ============================================================
# TEST: export skips already-exported issues
# ============================================================
run_test
output="$(git issue export github:testowner/testrepo 2>&1)"
case "$output" in
	*"Synced"*|*"#42"*)
		# Should sync, not re-export
		ref_count="$(git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
		if test "$ref_count" -eq 1
		then
			pass "re-export syncs rather than duplicating"
		else
			fail "re-export syncs rather than duplicating" "ref count: $ref_count"
		fi
		;;
	*)
		fail "re-export syncs rather than duplicating" "output: $output"
		;;
esac

# ============================================================
# TEST: export includes comments
# ============================================================
run_test
setup_repo
create_mock_gh
chmod +x "$TEST_DIR/mock-bin/gh"
# Create issue with comments
out="$(git issue create "Issue with comments" 2>&1)"
id="$(printf '%s' "$out" | sed 's/Created issue //')"
git issue comment "$id" -m "First comment" >/dev/null
git issue comment "$id" -m "Second comment" >/dev/null
# Track API calls to verify comments are exported
cat > "$TEST_DIR/mock-bin/gh" <<MOCKEOF4
#!/bin/sh
case "\$*" in
	"auth status") exit 0 ;;
	*"--method POST"*"/comments"*)
		echo '{"id": 999}'
		echo "COMMENT_EXPORTED" >> "$TEST_DIR/export-log"
		;;
	*"--method POST"*"/issues"*)
		echo '{"number": 50}'
		;;
	*"--method PATCH"*) echo '{}' ;;
	*) echo "mock-gh: unhandled: \$*" >&2; exit 1 ;;
esac
MOCKEOF4
chmod +x "$TEST_DIR/mock-bin/gh"
rm -f "$TEST_DIR/export-log"
git issue export github:testowner/testrepo >/dev/null 2>&1
comment_exports="$(wc -l < "$TEST_DIR/export-log" 2>/dev/null | tr -d ' ')"
if test "$comment_exports" -eq 2
then
	pass "export includes comments"
else
	fail "export includes comments" "expected 2 comment exports, got ${comment_exports:-0}"
fi

# ============================================================
# TEST: export syncs closed state
# ============================================================
run_test
setup_repo
# Create and close an issue
out="$(git issue create "Will close for export" 2>&1)"
id="$(printf '%s' "$out" | sed 's/Created issue //')"
git issue state "$id" --close >/dev/null
cat > "$TEST_DIR/mock-bin/gh" <<MOCKEOF5
#!/bin/sh
case "\$*" in
	"auth status") exit 0 ;;
	*"--method POST"*"/comments"*) echo '{"id": 999}' ;;
	*"--method POST"*"/issues"*)
		echo '{"number": 55}'
		;;
	*"--method PATCH"*)
		echo "STATE_SYNCED" >> "$TEST_DIR/state-log"
		echo '{}'
		;;
	*) echo "mock-gh: unhandled: \$*" >&2; exit 1 ;;
esac
MOCKEOF5
chmod +x "$TEST_DIR/mock-bin/gh"
rm -f "$TEST_DIR/state-log"
git issue export github:testowner/testrepo >/dev/null 2>&1
if test -f "$TEST_DIR/state-log"
then
	pass "export syncs closed state to GitHub"
else
	fail "export syncs closed state to GitHub" "no state sync API call"
fi

# ============================================================
# TEST: export --dry-run does not create GitHub issues
# ============================================================
run_test
setup_repo
create_mock_gh
chmod +x "$TEST_DIR/mock-bin/gh"
git issue create "Dry run export test" >/dev/null
output="$(git issue export github:testowner/testrepo --dry-run 2>&1)"
# Should not have Provider-ID
ref="$(git for-each-ref --format='%(refname)' refs/issues/ | head -1)"
pid="$(git log --format='%(trailers:key=Provider-ID,valueonly)' "$ref" | sed '/^$/d' | sed 's/^[[:space:]]*//' | head -1)"
if test -z "$pid"
then
	case "$output" in
		*"dry-run"*"Would export"*)
			pass "export --dry-run shows plan but does not export"
			;;
		*)
			fail "export --dry-run shows plan but does not export" "output: $output"
			;;
	esac
else
	fail "export --dry-run shows plan but does not export" "Provider-ID was recorded: '$pid'"
fi

# ============================================================
# TEST: export outside git repo fails
# ============================================================
run_test
tmpdir="$(mktemp -d)"
cd "$tmpdir"
if git issue export github:testowner/testrepo 2>/dev/null
then
	fail "export outside git repo fails" "should have failed"
else
	pass "export outside git repo fails"
fi
rm -rf "$tmpdir"

# ============================================================
# TEST: export with invalid provider string fails
# ============================================================
run_test
setup_repo
if git issue export "badprovider" 2>/dev/null
then
	fail "export with invalid provider string fails" "should have failed"
else
	pass "export with invalid provider string fails"
fi

# ============================================================
# TEST: export skips foreign imports
# ============================================================
run_test
setup_repo
create_mock_gh
chmod +x "$TEST_DIR/mock-bin/gh"
# Import from one repo
git issue import github:testowner/testrepo --state all >/dev/null 2>&1
# Try to export to a different repo
output="$(git issue export github:otherowner/otherrepo 2>&1)"
case "$output" in
	*"Skipped"*"imported from"*)
		pass "export skips issues imported from a different repo"
		;;
	*)
		fail "export skips issues imported from a different repo" "output: $output"
		;;
esac

# ============================================================
# TEST: round-trip import then export sync
# ============================================================
run_test
setup_repo
create_mock_gh
chmod +x "$TEST_DIR/mock-bin/gh"
# Import from a repo
git issue import github:testowner/testrepo --state all >/dev/null 2>&1
# Export back to the same repo (should sync, not duplicate)
output="$(git issue export github:testowner/testrepo 2>&1)"
ref_count="$(git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
case "$output" in
	*"Synced"*)
		if test "$ref_count" -eq 2
		then
			pass "round-trip: import then export syncs without duplicating"
		else
			fail "round-trip: import then export syncs without duplicating" "ref count: $ref_count"
		fi
		;;
	*)
		fail "round-trip: import then export syncs without duplicating" "output: $output"
		;;
esac

# ============================================================
# SYNC TESTS
# ============================================================

# ============================================================
# TEST: export prints summary with correct counts
# ============================================================
run_test
setup_repo
create_mock_gh
chmod +x "$TEST_DIR/mock-bin/gh"
git issue create "Count test 1" >/dev/null
git issue create "Count test 2" >/dev/null
output="$(git issue export github:testowner/testrepo 2>&1)"
case "$output" in
	*"Exported 2 issues (0 skipped, 0 synced)"*)
		pass "export prints summary with correct counts"
		;;
	*)
		fail "export prints summary with correct counts" "output: $output"
		;;
esac

# ============================================================
# TEST: sync runs import then export
# ============================================================
run_test
setup_repo
create_mock_gh
chmod +x "$TEST_DIR/mock-bin/gh"
output="$(git issue sync github:testowner/testrepo --state all 2>&1)"
case "$output" in
	*"Importing from"*"Exporting to"*)
		pass "sync runs import then export"
		;;
	*)
		fail "sync runs import then export" "output: $output"
		;;
esac

# ============================================================
# TEST: sync --dry-run passes through
# ============================================================
run_test
setup_repo
create_mock_gh
chmod +x "$TEST_DIR/mock-bin/gh"
output="$(git issue sync github:testowner/testrepo --state all --dry-run 2>&1)"
ref_count="$(git for-each-ref --format='x' refs/issues/ | wc -l | tr -d ' ')"
if test "$ref_count" -eq 0
then
	case "$output" in
		*"dry-run"*)
			pass "sync --dry-run passes through without changes"
			;;
		*)
			fail "sync --dry-run passes through without changes" "output: $output"
			;;
	esac
else
	fail "sync --dry-run passes through without changes" "created $ref_count refs"
fi

# ============================================================
# TEST: sync with invalid provider fails
# ============================================================
run_test
setup_repo
if git issue sync "badprovider" 2>/dev/null
then
	fail "sync with invalid provider fails" "should have failed"
else
	pass "sync with invalid provider fails"
fi

# ============================================================
# SUMMARY
# ============================================================
printf "\n%.60s\n" "============================================================"
printf "Tests: %d | Passed: ${GREEN}%d${NC} | Failed: ${RED}%d${NC}\n" \
	"$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf "%.60s\n" "============================================================"

if test "$TESTS_FAILED" -gt 0
then
	exit 1
fi
