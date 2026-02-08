# Expert Council Debate: git-issue v1.0.0

**Date**: 2026-02-08
**Moderator**: Claude Opus 4.6 (Agent Team)
**Purpose**: Adversarial review of git-issue v1.0.0 implementation and mailing list submission strategy

---

## Round 1: Initial Reactions

### Linus Torvalds

I said "git for bugs" back in 2007, and people have been overthinking it ever since. This one... actually might not be overthinking it.

The format spec is good. Commits, refs, trailers. That's it. No JSON. No SQLite. No "let me reinvent half of git because I'm smarter than everyone else." You're using git as git. That's rare.

But here's my issue with the mailing list email: you're asking for "format blessing" like we're some kind of standards body. We're not. We don't bless formats. We write code. If you want this in git.git, send patches. If you don't want it in git.git, don't ask us to bless your thing.

The "production use for one year" claim is... generous. You're the only user. That's not production. That's dogfooding. Don't oversell it.

**Grade**: B+ for implementation, D for mailing list strategy.

---

### Junio Hamano (gitster)

This is surprisingly well-thought-out. I appreciate the ABNF grammar, the explicit non-goals, the minimum Git version requirement (2.17 is reasonable), and the security considerations section. The specification reads like someone who has read gitformat-pack(5).

However, I have serious concerns about submitting this to git@vger.kernel.org right now:

1. **One implementation, zero ecosystem adoption** -- You want us to bless a format that only you have implemented. What if GitHub implements it differently? What if the format has a flaw that only surfaces when GitLab tries to adopt it? You need at least TWO independent implementations before standardization.

2. **Merge strategy is heuristic, not proven** -- Last-writer-wins and three-way set merge are fine for low-conflict scenarios, but the spec admits (Section 6.6) that conflicts can occur. You haven't implemented conflict representation. That's a hole in the spec.

3. **No implementation in git.git** -- The email says "this is not a proposal to merge a tool into Git" but also asks if we'd consider a gitformat-issue(5) man page. Which is it? We don't document formats we don't implement.

4. **Title override is specified but not implemented** -- Section 6.5 defines `Title:` trailer overrides, but your implementation review admits this isn't done. That's a mismatch between spec and implementation.

My recommendation: **Wait 6 months**. Get a second implementation (maybe a Python library, or a Go port). Ship v1.1 with title overrides implemented. Get actual multi-user feedback. Then come back.

**Grade**: A- for spec quality, C for timing.

---

### Michael Mure (git-bug author)

I've been running git-bug for 7 years now. I know the pain of distributed issue tracking. So let me be blunt: this format is simpler than git-bug, which is good and bad.

**The good:**
- You admit you're using heuristics instead of CRDTs. That's honest.
- The three-way set merge for labels is clever -- it's not mathematically proven like a G-Set, but it handles 90% of cases.
- The spec is standalone. git-bug never had this. You're right that it's a differentiator.

**The bad:**
- Last-writer-wins for state is fragile. What if two people close the same issue within the same second? SHA tiebreaker works, but it's arbitrary. One person's close reason wins, the other's is lost. No conflict is raised.
- You defer conflict representation to "when needed." I've seen this in git-bug: users merge, lose data silently, and don't realize it until weeks later. You need conflict representation NOW.
- You claim "zero unresolvable conflicts in 8 months" but you're the only user. Of course there are no conflicts -- you're not racing yourself.

**The question:**
Why not just contribute to git-bug instead of fragmenting the space? We could add a "simple mode" that uses your trailer format as an alternative to the CRDT operations. Then we'd have two implementations of your format immediately.

I'm not opposed to your format, but I think you're 6-12 months too early for standardization. Get more users first.

**Grade**: B for technical design, C- for ecosystem strategy.

---

### D. Richard Hipp (Fossil creator)

I created Fossil in 2006 specifically because issue tracking should be in the same repository as code. So I'm sympathetic to your goals. But I have two major concerns:

**1. Shell scripts are not production-grade**

You have 2,897 lines of POSIX shell. That's impressive engineering, but it's the wrong language for a foundational tool. Shell is:
- Slow (subprocess spawning for every git command)
- Error-prone (quote handling, whitespace sensitivity)
- Hard to test (you have 153 tests, but 100% coverage is impossible in shell)
- Not portable (POSIX compliance is a myth -- every shell has quirks)

Fossil's ticket system is 50,000+ lines of C with SQLite for performance. You're using `git for-each-ref` and claiming it scales to 10,000 issues. Prove it. Show me benchmark data.

**2. The mailing list email is too academic**

You're writing like you're submitting a paper to a conference. The git community doesn't care about "Non-Goals sections" or "ABNF grammars." They care about patches. The email should be:

1. Here's a problem (30 words)
2. Here's my solution (50 words)
3. Here's the patch series (inline)

Your email is 172 lines of prose before the spec even starts. That's too long. Junio will read the first 20 lines and archive it.

**Recommendation:** Rewrite the tool in C. Port it to libgit2. Show performance benchmarks. Then come back. Shell scripts are for prototypes, not standards.

**Grade**: A for ambition, D for implementation language, F for mailing list readability.

---

### Diomidis Spinellis (git-issue original author)

I wrote git-issue in 2016 as a weekend project. It's 500 lines of shell, does the job, and I still use it. So I'm the target audience for your tool, and here's my take:

**What I like:**
- You built it. Most people just talk about distributed issue tracking. You shipped code.
- The format is simple. UUIDs, trailers, refs. I can understand it in 5 minutes.
- The dogfooding is real. You're using this tool to track its own issues. That matters.

**What worries me:**
- You're trying to standardize before you have users. I wrote git-issue, published it, and got ~500 GitHub stars. Then I moved on. No one asked for a format spec. No one asked for standardization. People just used it or didn't.
- The mailing list email is asking for "blessing" instead of contribution. If you want git-issue in contrib/, send patches. If you want to stay independent, stay independent. But don't ask the git project to endorse your external tool. That's not how it works.

**The format spec question:**
Is a standalone format spec actually useful? You claim it enables "multiple independent implementations" but who's going to implement it? GitHub won't. GitLab won't. Forgejo might, if you convince them directly, but a format spec on git@vger won't change that.

The real path to adoption is:
1. Make the tool so good that people use it
2. Build bridges to GitHub/GitLab so migrations are easy
3. Wait for platforms to notice and add native support

You're trying to skip to step 3 via standardization. That won't work.

**Recommendation:** Ship v1.0, announce it on Hacker News, get real users, collect feedback, iterate. Come back to the mailing list in a year if the tool has adoption. Don't ask for blessing -- earn it through usage.

**Grade**: A for pragmatism in implementation, C for premature standardization.

---

## Round 2: Mailing List Email Critique

### Linus Torvalds

The subject line is wrong. `[RFC] Distributed Issue Tracking Format` sounds like a proposal for git.git. If it's not, say so clearly: `[RFC] External format spec for review`.

The opening paragraph is too defensive: "This is NOT a proposal to merge a tool into Git" -- if you have to say that in the first sentence, your framing is wrong. Just say what you want: "I have a format spec for issue tracking using git refs. Feedback welcome."

The "Background" section is wasted space. Don't tell me about Linus's 2007 quote (I know, I was there). Don't list prior art -- that's for your README, not the mailing list. Get to the point.

The "Request for Format Blessing" section is naive. We don't bless formats. We review patches. If you want git.git to ship a gitformat-issue(5) man page, send the man page as a patch. If you want feedback on your design, ask specific questions.

**Line-by-line fixes:**

- **Line 1-10**: Cut to 3 lines: "I built a distributed issue tracker using git refs and trailers. Looking for feedback on the format spec before broader adoption."
- **Line 12-32 (Background)**: Delete entirely. Move to your blog post.
- **Line 75-88 (Request for Blessing)**: Rephrase as: "If this format proves useful, I'd like to submit a gitformat-issue(5) man page to git.git. Feedback on whether this is a good fit for contrib/ is welcome."
- **Line 126-142 (Questions)**: Good, keep these, but move them earlier (line 15).

**Verdict:** The email is 50% too long and asks for something we don't give. Rewrite it as a technical review request, not a standardization petition.

---

### Junio Hamano

The email structure is backwards. You should lead with:
1. The technical design (commits, refs, trailers)
2. The specific questions you want answered
3. The broader context (prior art, production use)

Instead, you lead with context and bury the technical meat in line 35-50. By the time I get to the actual proposal, I've already lost interest.

**Specific issues:**

- **Line 64-73 (Production Use)**: "Approximately one year" is vague. Say "8 months" or "since April 2025." Be precise.
- **Line 65**: "The reference implementation is a POSIX shell tool" -- this will make people dismiss it immediately. Shell tools don't become standards. If you want this taken seriously, you need a C implementation or at least a libgit2 binding.
- **Line 106-114 (Comparison to Prior Art)**: This is valuable but too brief. The comparison to git-dit is one sentence. That should be a paragraph -- git-dit is your closest prior art and you should explain why it failed and how you're different.
- **Line 143-152 (Next Steps)**: Don't tell us your roadmap. We don't care about your Forgejo discussions or your Homebrew tap. Just ask for feedback.

**Tone issues:**

The email reads like a grant proposal, not a technical discussion. You're trying to convince us to endorse your project. That's not how the git community works. You should be asking: "I built this thing. Does it have obvious flaws I missed?"

**Questions for the Community section (line 126-142):**

These are good questions, but they're too open-ended. Narrow them:

- Question 1 (refs namespace): Yes, this is the right question. Keep it.
- Question 2 (merge rules): Too vague. Ask specifically: "Does last-writer-wins for state create unacceptable data loss in multi-user scenarios?"
- Question 3 (Git version): Irrelevant. If you need 2.17, you need 2.17.
- Question 4 (security): Good, keep.
- Question 5 (gitformat-issue man page): This is the only question that matters. Make it question 1.

**Verdict:** The email is technically sound but strategically confused. You're asking for a blessing we can't give. Ask for a technical review instead.

---

### Michael Mure

The comparison to git-bug (line 106) is weak. You say "this format uses simpler heuristics instead of CRDTs" but you don't explain WHY that's better. From a correctness standpoint, it's worse. LWW loses data. Three-way set merge has corner cases. CRDTs don't.

The only advantage of your approach is simplicity, but you don't sell that. You should say:

> "Unlike git-bug's CRDT model, this format uses last-writer-wins and three-way set merge. This trades mathematical correctness for implementation simplicity and human readability. For projects with low concurrency (1-5 contributors), the simpler model is sufficient and easier to debug."

That's honest. That's defensible. The current email just handwaves the difference.

**Production Use section (line 64-73):**

You claim 106 tests and 16 issues tracked. That's not production use. That's development. Production use is: "10 open-source projects with 50+ contributors each have used this format for 6+ months." You don't have that data, so don't claim production readiness.

**The mailing list won't adopt your format based on one user's experience.** You need to show that the format works for diverse projects, not just your own dogfooding.

**Verdict:** The email oversells the maturity and undersells the trade-offs. Be more honest about both.

---

### D. Richard Hipp

The email is too long. I maintain Fossil and I get emails like this all the time. Here's what I do:

1. Read the subject line (10 seconds)
2. Read the first paragraph (30 seconds)
3. Decide if I'm interested (decision point)
4. If interested, skim the rest

Your email fails step 3. The first paragraph says "this is not a proposal to merge into Git" so I stop reading. Why should I spend time on something that's not relevant to Git?

**What you should do:**

Make the first paragraph say: "I want to submit a gitformat-issue(5) man page to git.git's documentation. Here's the format. Does this belong in contrib/ or should it stay external?"

That's a yes/no question. Junio can answer it in one line. Then you have a decision, not a vague "blessing."

**The spec itself:**

700 lines of ABNF, trailers, and merge rules is too much for inline email. Just link to GitHub and paste the 3-paragraph Abstract section. The mailing list doesn't need to see the ABNF grammar.

**Verdict:** Cut the email to 50 lines. Link to the spec. Ask a yes/no question. Done.

---

### Diomidis Spinellis

The email is a research paper disguised as a technical proposal. Look at this structure:

- Abstract (implied by intro)
- Background (prior art)
- Proposal (technical design)
- Production Use (evaluation)
- Comparison to Prior Art (related work)
- Questions for Community (discussion)
- Next Steps (conclusion)

This is an academic paper format, not a mailing list email. The git community doesn't work like this.

**What works in the git community:**

1. Peff (Jeff King) sends a 5-line email with a patch attached: "I noticed git-log is slow for huge repos. Here's a fix."
2. Junio reviews it in 2 lines: "Makes sense. Applied."

That's the culture. Your email is fighting that culture by being too formal, too long, and too ambitious.

**The "Production Use" section is the worst offender:**

You list 106 tests, 16 issues, and "zero critical bugs" like you're submitting a paper to SIGCOMM. The git community doesn't care about test counts. They care about: "Does this solve a real problem that real people have?"

You haven't shown that. You've shown that YOU have this problem and YOU solved it for yourself. That's fine, but it's not enough for standardization.

**Verdict:** Strip out all the academic trappings. Write like you're asking a friend for code review, not submitting to a journal.

---

## Round 3: Technical Deep Dive

### Linus: Challenge Complexity

**Linus:** The format spec is 641 lines. My original "git for bugs" idea was: use git. That's it. Why do you need 641 lines to explain "store issues as commits"?

**Moderator (as spec author):** The spec covers edge cases: merge rules, security (trailer injection, command injection), transport (shallow clones, protocol v2), format evolution (Format-Version trailer), bridge protocol for GitHub import/export. These are real problems that prior art (git-dit, git-appraise) didn't solve, which is why they failed.

**Linus:** You're over-engineering. Look at Section 6 (Merge Rules). You have:
- Comments: append-only (fine)
- State: last-writer-wins (fine)
- Labels: three-way set merge (what?)
- Scalar fields: last-writer-wins (redundant with state)
- Title override: optional trailer (why?)
- Merge commit format: specified (overkill)
- Conflict representation: specified but not implemented (????)

Half of this is unnecessary. If you just used "last-writer-wins for everything" and "comments are append-only," you'd have a 200-line spec. The three-way set merge for labels is clever, but is it worth the complexity?

**Moderator:** The three-way set merge prevents label loss when two people add different labels concurrently. Without it, one person's labels overwrite the other's.

**Linus:** So what? If labels conflict, the last writer wins. Users can fix it manually. You're adding merge logic for a feature (labels) that most issue trackers barely use. GitHub issues have labels. GitLab calls them tags. Jira has components. You can't standardize something that isn't even standardized across platforms.

**Verdict:** Linus thinks the spec is 3x too complex. He'd cut everything but commits, refs, and trailers. No merge rules beyond "fast-forward or manual."

---

### Junio: Probe Edge Cases

**Junio:** Section 6.3 (three-way set merge for labels) has a tiebreaker: "if one side added a label and the other removed it, the addition wins." Why?

**Moderator:** Bias toward keeping data. If Alice adds "urgent" and Bob removes "urgent," we assume Alice has newer information.

**Junio:** But what if Bob removed it because the issue was resolved? Now you're re-adding a stale label. That's a semantic error.

**Moderator:** True, but the alternative (removal wins) has the opposite problem: Bob accidentally deletes Alice's label.

**Junio:** The real problem is that you're trying to merge semantic meaning (labels represent issue urgency) with syntactic rules (set operations). Labels aren't just strings -- they have meaning. Your merge rule doesn't understand that meaning.

**Example edge case:**

1. Base: `Labels: bug`
2. Alice: `Labels: bug, urgent` (adds urgent)
3. Bob: `Labels: bug, wontfix` (adds wontfix, implying we won't fix it)
4. Your merge: `Labels: bug, urgent, wontfix`

Now the issue is labeled both "urgent" and "wontfix" which is contradictory. Your three-way merge can't detect this because it doesn't understand that "urgent" and "wontfix" are semantically incompatible.

**Moderator:** That's a good point. The spec should document this limitation. The alternative is to require manual conflict resolution for labels, which defeats the purpose of automatic merging.

**Junio:** Exactly. Which is why I think you're not ready to standardize. You have a semantic problem disguised as a syntactic solution.

**Verdict:** Junio found a real flaw in the label merge strategy. The spec needs to acknowledge that semantic conflicts can't be auto-resolved.

---

### Michael: Compare to CRDT Approach

**Michael:** In git-bug, we use a G-Set CRDT for labels. It's append-only: you can add labels, but removing a label just adds a "remove" operation. When merging, all operations are preserved, and the final set is computed deterministically.

Your three-way set merge is similar, but it's NOT a CRDT. Here's why:

1. **CRDTs are associative and commutative:** `merge(A, merge(B, C)) = merge(merge(A, B), C)`. Your three-way merge is NOT associative if there are >2 participants.

2. **Example:**
   - Base: `{bug}`
   - Alice: `{bug, ui}` (adds ui)
   - Bob: `{bug, backend}` (adds backend)
   - Carol: `{bug}` (removes nothing)

   **Two-way merge (Alice + Bob):** `{bug, ui, backend}` ✓
   **Three-way merge (Alice + Bob + Carol):** Who's the base? If Carol is the base, then Alice and Bob both added labels relative to Carol, so result is `{bug, ui, backend}`. But if the original base is used, Carol's branch is a no-op. Your spec doesn't define N-way merges.

**Moderator:** The spec assumes pairwise merges (Section 6.7). If there are three divergent branches, you merge them two at a time.

**Michael:** That works, but it's not explained in the spec. Also, pairwise merges can have different results depending on merge order. That's a hidden complexity.

**Verdict:** Michael confirmed that the three-way set merge is simpler than CRDTs but has edge cases the spec doesn't document.

---

### Richard: Question Shell Scripts

**Richard:** Let's talk performance. You claim `git for-each-ref` scales to 10,000 issues. Prove it.

**Moderator:** We ran benchmarks in `t/perf/`. For 1,000 issues, `git issue ls` takes 0.3 seconds. For 10,000 issues (simulated), it's ~3 seconds.

**Richard:** That's slow. Fossil's ticket list is <0.1 seconds for 10,000 tickets because we use SQLite with indexes. Your `git for-each-ref` is doing a linear scan.

**Moderator:** True, but git-issue doesn't need to be faster than Fossil. It needs to be fast enough for real repos. Most projects have <1,000 issues.

**Richard:** "Fast enough" is not a design principle. What happens when someone imports 50,000 GitHub issues from the Linux kernel? Your tool becomes unusable.

**Moderator:** The spec recommends shallow clones (`--depth=1`) for large repos. That limits history but keeps the current state fast.

**Richard:** So your solution to "too many issues" is "don't fetch all the issues." That's a workaround, not a solution.

**Another issue:** Shell scripts parse trailer output with `grep` and `awk`. What if a trailer value contains a newline? Your spec says (Section 11.1) "implementations MUST validate that trailer values do not contain newlines" but how do you validate input that's already in the commit?

**Moderator:** The validation happens at creation time (git-issue-create, git-issue-edit). If a malicious user manually crafts a commit with an embedded newline, git-issue-show will mis-parse it.

**Richard:** So your format is only secure if everyone uses your tool? That's not a format spec, that's a tool spec. A real format spec would say: "Trailer values are percent-encoded" or "use RFC 822 folding" so that ANY implementation can parse it correctly.

**Verdict:** Richard found a security hole (newline injection in trailer values) and a performance bottleneck (linear scan for large repos).

---

### Diomidis: Assess Pragmatism

**Diomidis:** I like that you shipped shell scripts. They're portable, auditable, and easy to modify. But I agree with Richard that shell is a liability for performance.

Here's my question: Is the format spec useful independent of the tool?

You claim that GitHub/GitLab could implement native `refs/issues/*` support. Let's test that. If I'm a GitLab engineer, what do I need to do?

1. Read ISSUE-FORMAT.md (641 lines)
2. Implement commit parsing (easy)
3. Implement trailer extraction (easy)
4. Implement merge rules (hard -- three-way set merge is complex)
5. Implement conflict representation (specified but you didn't implement it)
6. Implement bridge protocol (specified but deferred to plugins)

Steps 4-6 are under-specified. The spec SAYS how to merge labels, but there's no reference implementation in a real language (C, Go, Python). The only implementation is shell scripts with temp files and `comm`.

**If I were GitLab, I'd ignore your spec and just support git-bug's format.** Why? Because git-bug has 1.2k GitHub stars, 7 years of production use, and a real user base. Your format has 1 user (you).

**The pragmatic path:**

1. Ship your tool
2. Get 100+ real users (not test repos, real projects)
3. Collect feedback on what breaks (merge conflicts, performance, UX)
4. Iterate to v2.0
5. Then write the format spec based on what actually works

You did it backwards: spec first, users later. That's academic, not pragmatic.

**Verdict:** Diomidis thinks the format spec is premature. Ship the tool, get users, then standardize.

---

## Round 4: Strategic Questions

### Should we submit to the mailing list NOW or wait?

**Linus:** Don't submit now. You're asking for something we can't give (format blessing). If you want to contribute to git.git, send patches for contrib/. If you want to stay independent, just ship and iterate. The mailing list is not your marketing channel.

**Junio:** Wait 6 months. Get a second implementation (Python, Go, Rust). Fix the edge cases we found (label semantic conflicts, newline injection, N-way merges). Ship v1.1 with conflict representation implemented. Then come back with data: "We have 50 projects using this, here's what we learned."

**Michael:** Wait 12 months. One year of single-user dogfooding is not enough to validate a distributed merge strategy. You need at least 3-5 projects with multiple contributors racing to update issues. Then you'll find the real conflicts your merge rules can't handle.

**Richard:** Don't submit at all. The git mailing list is for git.git development. Your tool is external. If you want adoption, convince Forgejo, Gitea, or GitLab to implement it. They're the platforms that matter, not git@vger.

**Diomidis:** Submit in 12-18 months, after you have real adoption. The mailing list is a last step, not a first step. You're trying to standardize before you have proof the format works.

**Vote:**
- **Submit now:** 0/5
- **Wait 3 months:** 0/5
- **Wait 6 months:** 1/5 (Junio, conditional on second implementation)
- **Wait 12+ months:** 3/5 (Michael, Diomidis, Richard)
- **Don't submit:** 1/5 (Linus)

---

### Is the format spec approach the right strategy?

**Linus:** No. Formats emerge from tools, not the other way around. Git's object format wasn't designed in a vacuum -- it evolved from what git-core needed. You should build the tool first, let the format stabilize, then document it.

**Junio:** Yes, but only if you have multiple implementations. A format spec with one implementation is just documentation. A format spec with three implementations is a standard.

**Michael:** Partially. The idea of a standalone spec is good, but it's too early. Write the spec after you have users, not before.

**Richard:** No. Standards bodies (IETF, W3C) write specs. Open source projects write code. You're acting like a standards body but you don't have the authority or process. Just ship the tool.

**Diomidis:** The spec is a nice-to-have, but it's not the bottleneck. The bottleneck is adoption. Focus on making the tool so good that people use it despite the lack of a spec. Then write the spec to document what emerged.

**Vote:**
- **Format spec is the right strategy:** 1/5 (Junio, with caveats)
- **Format spec is premature:** 4/5 (Linus, Michael, Richard, Diomidis)

---

### What are the risks of submitting now?

**Linus:** You'll get ignored or dismissed. The mailing list gets dozens of "I have a great idea for Git" emails every month. Most get no response. Yours will too, because you're asking for something we don't do (bless external formats).

**Junio:** You'll get feedback, but it'll be critical (like this review). If you're not ready for that, it'll demoralize you. Better to wait until you have data to defend your design.

**Michael:** The format might have flaws (we found several) that get baked in if you standardize too early. Then you're stuck with a bad spec that people have implemented.

**Richard:** You'll waste time. The mailing list isn't your target audience. Your target audience is Forgejo, Gitea, GitLab. Go talk to them directly.

**Diomidis:** You'll look amateurish. Asking for "blessing" makes you sound like you don't understand how open source works. Just ship and let the work speak for itself.

**Consensus:** Submitting now is low-reward (won't get blessing) and moderate-risk (might get ignored or criticized, wasting time).

---

### What should the mailing list email say (if we do submit)?

**All five agree:** If you submit despite our advice, the email should be:

1. **Subject:** `[RFC] Proposal for gitformat-issue(5) man page in git.git/contrib`
2. **Body (20 lines max):**
   - "I built a distributed issue tracker using git refs and trailers."
   - "I'd like to contribute the format spec as a man page in contrib/."
   - "The format has been in use for 8 months on my project. Spec attached."
   - "Questions: (1) Is contrib/ the right place? (2) Any objections to refs/issues/* namespace? (3) Security concerns beyond those in Section 11?"
3. **Attachment:** ISSUE-FORMAT.md (inline, trimmed to 300 lines max)

**What to cut:**
- All prior art discussion (save for your blog)
- All "production use" claims (you have 1 user, be honest)
- All "roadmap" and "next steps" (irrelevant to git.git)
- All "Request for Blessing" framing (just ask for code review)

---

## Round 5: Blackboard Synthesis

### APPROVED (Unanimous or 4-1)

1. **UUIDs for identity** -- All five agree this is the right choice over sequential IDs
2. **Commits + trailers for metadata** -- Better than JSON, YAML, or custom formats
3. **Empty tree usage** -- Correct optimization, no objections
4. **refs/issues/* namespace** -- No conflicts with Git's existing refs
5. **Minimum Git 2.17 requirement** -- Reasonable, not controversial
6. **Last-writer-wins for scalar fields** -- Simple and good enough for low-concurrency scenarios
7. **Comments as append-only commits** -- Correct design, no conflicts possible
8. **Import/export bridge strategy** -- Deferring live sync is the right prioritization

### CONCERNS (Need Addressing Before Submission)

#### CRITICAL (Must Fix)

1. **Newline injection in trailer values (Richard)** -- SEVERITY: HIGH
   - The spec says "implementations MUST validate" but doesn't define how to parse untrusted commits
   - Fix: Add percent-encoding or RFC 822 folding to the spec, not just validation requirements

2. **Label semantic conflicts (Junio)** -- SEVERITY: MEDIUM
   - Three-way set merge can produce contradictory labels (`urgent` + `wontfix`)
   - Fix: Add a "Limitations" subsection to Section 6.3 documenting semantic conflicts

3. **N-way merge ordering (Michael)** -- SEVERITY: MEDIUM
   - Spec assumes pairwise merges but doesn't define merge order for 3+ divergent branches
   - Fix: Add Section 6.9 "N-Way Merges" explaining pairwise reduction

4. **Conflict representation not implemented (Junio, Michael)** -- SEVERITY: MEDIUM
   - Section 6.8 specifies conflict trailers but implementation review admits it's not done
   - Fix: Either implement it in v1.1 or move it to "Future Extensions" (Section 12)

#### MODERATE (Should Fix)

5. **Title override not implemented** -- SEVERITY: LOW
   - Section 6.5 defines `Title:` trailer but git-issue-edit doesn't support it
   - Fix: Implement in v1.1 or document as optional extension

6. **Production use oversold (Linus, Diomidis)** -- SEVERITY: MEDIUM (marketing)
   - "One year of production use" is really "8 months of single-user dogfooding"
   - Fix: Be precise and honest in all claims

7. **Performance claims unproven (Richard)** -- SEVERITY: LOW
   - "Scales to 10,000 issues" based on simulation, not real repos
   - Fix: Add benchmark section to docs with caveats

#### ADVISORY (Nice to Have)

8. **Second implementation needed (Junio, Diomidis)** -- SEVERITY: HIGH (for standardization)
   - Only one implementation exists (shell scripts)
   - Recommendation: Wait for Python/Go/Rust port before mailing list submission

9. **Real multi-user testing (Michael)** -- SEVERITY: HIGH (for validation)
   - Zero observed conflicts because only one user
   - Recommendation: Get 3-5 projects with 5+ contributors each to test merge rules

---

### REJECTED

1. **Submitting to mailing list now** -- 5/5 REJECT
   - Too early, need more validation
   - Wrong audience (git.git vs platforms)
   - Wrong ask (blessing vs code review)

2. **Shell scripts as final implementation (Richard)** -- 4/5 REJECT (Diomidis dissents)
   - Not performant enough for large repos
   - Not suitable for standardization
   - Need C/Go/Rust for serious adoption

3. **Current mailing list email text** -- 5/5 REJECT
   - Too long (172 lines before spec)
   - Too academic (reads like a paper)
   - Wrong framing (asking for blessing)

---

### RECOMMENDATIONS

#### For the Mailing List Email (if you submit despite advice)

1. **Cut the email to <50 lines** -- Remove Background, Production Use, Comparison sections
2. **Change subject** -- `[RFC] Proposal for gitformat-issue(5) in contrib/` not "format blessing"
3. **Lead with technical design** -- Commits, refs, trailers (3 sentences)
4. **Ask specific yes/no questions** -- Not "bless this format" but "objections to refs/issues/*?"
5. **Be honest about maturity** -- "8 months single-user use" not "production for one year"
6. **Link to spec, don't inline** -- Paste Abstract only, link to GitHub for full text
7. **Remove all roadmap/next steps** -- git.git doesn't care about your Forgejo discussions

#### For the Implementation

1. **Fix newline injection** -- Add trailer value encoding to spec (percent-encode or fold)
2. **Document label semantic conflicts** -- Add Limitations subsection
3. **Implement conflict representation OR defer to v2** -- Don't have half-specified features
4. **Add N-way merge section** -- Explain pairwise reduction
5. **Implement title override OR remove from spec** -- Match spec to implementation

#### For the Spec

1. **Move Format-Version 1 to "stable"** -- Change Status from "Draft" to "Stable" only after fixes above
2. **Add "Limitations" section** -- Document known edge cases (semantic label conflicts, LWW data loss)
3. **Add "Implementation Guidance"** -- Pseudocode for three-way set merge, not just prose
4. **Reduce length by 30%** -- Consolidate redundant sections, move examples to appendix

#### For Adoption Strategy

1. **Wait 6-12 months before mailing list submission** (Unanimous)
2. **Get a second implementation** -- Python library or Go port (Junio, Diomidis)
3. **Get real multi-user projects** -- 3-5 teams with 5+ contributors each (Michael)
4. **Talk to platforms directly** -- Forgejo, Gitea, Codeberg (Richard)
5. **Announce v1.0 on Hacker News** -- Get users first, standardize later (Diomidis, Linus)
6. **Rewrite in C or Go** -- Shell is a prototype language, not production (Richard, Junio)

---

### FINAL VOTE: Submit Now / Wait 3 Months / Wait 6 Months / Don't Submit

| Persona | Vote | Reasoning |
|---------|------|-----------|
| **Linus** | **Don't submit** | Mailing list is for git.git patches, not external format blessing |
| **Junio** | **Wait 6 months** | Need second implementation + conflict representation implemented |
| **Michael** | **Wait 12 months** | Need real multi-user testing to validate merge rules |
| **Richard** | **Don't submit to git.git, talk to platforms directly** | Wrong audience, focus on Forgejo/Gitea adoption |
| **Diomidis** | **Wait 12 months** | Get 100+ users, iterate to v2.0, then standardize |

**Tally:**
- Submit now: **0/5**
- Wait 3 months: **0/5**
- Wait 6 months: **1/5** (Junio, conditional on fixes)
- Wait 12+ months: **2/5** (Michael, Diomidis)
- Don't submit to git.git: **2/5** (Linus, Richard)

**Consensus:** DO NOT submit to git@vger.kernel.org now. Either wait 6-12 months (after second implementation + real users) OR skip git.git entirely and focus on platform adoption (Forgejo, Gitea).

---

## Moderator's Synthesis

The council found significant value in the format spec approach (all five praised the standalone spec idea) but unanimously rejected the timing and strategy for mailing list submission. Key themes:

1. **The format is sound but immature** -- LWW and three-way set merge work for single users but haven't been stress-tested with real multi-user concurrency.

2. **The spec has gaps** -- Newline injection, semantic label conflicts, N-way merges, and conflict representation are under-specified or unimplemented.

3. **One implementation is not enough** -- Without a second implementation (Python, Go, Rust), the spec might have hidden flaws that only surface during porting.

4. **The mailing list is the wrong venue** -- git@vger.kernel.org is for git.git development. For external tools, adoption comes from users, not standardization bodies.

5. **The email is too long and too academic** -- It reads like a research paper, not a technical proposal. The git community values brevity and code over prose.

**Recommended path forward:**

1. **Fix critical spec issues** (newline injection, label conflicts, N-way merges) -- 2 weeks
2. **Implement conflict representation OR defer to v2** -- 1 week
3. **Announce v1.0 on Hacker News, r/git, lobste.rs** -- Get organic users -- 1 month
4. **Port to Python or Go** (second implementation) -- 3 months
5. **Recruit 3-5 beta test projects** (multi-user testing) -- 6 months
6. **Iterate to v1.5 based on feedback** -- 6 months
7. **Approach Forgejo/Gitea directly** (platform adoption) -- Ongoing
8. **Consider mailing list submission** (only if you want contrib/ inclusion) -- 12+ months

**Final recommendation:** Ship v1.0 publicly, get users, iterate, then standardize. Don't ask for blessing -- earn it through adoption.

---

## Appendix: Line-by-Line Mailing List Email Rewrite

### CURRENT (172 lines, REJECTED)

```
To: git@vger.kernel.org
Subject: [RFC] Distributed Issue Tracking Format using Git Refs and Trailers

Hi Git community,

I am submitting for review a format specification for distributed issue
tracking that uses only Git's existing primitives: commits, refs, and
trailers. This is NOT a proposal to merge a tool into Git -- rather, it
is a request for feedback on a data format that could enable
interoperable issue tracking across Git implementations.

## Background

In 2007, Linus Torvalds proposed "a git for bugs" ...
[150 more lines]
```

### PROPOSED (42 lines, APPROVED by council)

```
To: git@vger.kernel.org
Subject: [RFC] Format spec for distributed issue tracking (contrib/ proposal)

Hi,

I've built a distributed issue tracker that stores issues as git refs
and trailers. I'd like to contribute the format spec to git.git as
contrib/issue-format/ISSUE-FORMAT.txt (similar to contrib/subtree/).

## Technical Design

Issues are stored as commit chains under refs/issues/<uuid>. Metadata
(state, labels, assignee) is in git trailers. Example:

  refs/issues/a7f3b2c1-4e5d-...
      |
      v
    [Close issue]         State: closed, Fixed-By: abc123
      |
    [Reproduced ...]      (comment)
      |
    [Fix login crash]     State: open, Labels: bug, Format-Version: 1

All commits use the empty tree. State computed via:
  git log --format='%(trailers:key=State,valueonly)' | head -1

Merge rules: LWW for state/assignee, three-way set merge for labels,
append-only for comments.

## Questions

1. Is contrib/issue-format/ the right place for this spec?
2. Any objections to using the refs/issues/* namespace?
3. Security concerns beyond trailer/command injection (Section 11 of spec)?
4. Should minimum Git version (2.17) be higher or lower?

## Status

- 8 months of use on my project (16 issues, 1 user)
- 153 tests, 15 commands, GitHub import/export working
- Format spec: https://github.com/remenoscodes/git-issue/blob/main/ISSUE-FORMAT.md

Full spec attached below (300 lines, trimmed to core sections).

Thanks,
Emerson
```

**Changes:**
- **Length:** 172 → 42 lines (75% reduction)
- **Framing:** "Format blessing" → "contrib/ proposal"
- **Tone:** Academic → Technical
- **Questions:** Open-ended → Yes/no
- **Claims:** "Production use" → "8 months, 1 user" (honest)

---

**End of Council Debate**
