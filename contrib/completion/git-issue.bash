# bash completion for git-issue
#
# Installation:
#   Source this file in your .bashrc or place it in /etc/bash_completion.d/
#
#   Option 1 - Source directly:
#     source /path/to/git-issue.bash
#
#   Option 2 - Copy to completions directory:
#     cp git-issue.bash /etc/bash_completion.d/git-issue
#
# This integrates with git's own completion system. If git-completion.bash
# is loaded, "git issue <TAB>" will work. The standalone "git-issue <TAB>"
# form is also supported.

# ---------------------------------------------------------------------------
# Helper: list issue short IDs (7-char abbreviated UUIDs)
# ---------------------------------------------------------------------------
__git_issue_ids() {
    git for-each-ref --format='%(refname:short)' refs/issues/ 2>/dev/null | \
        while IFS= read -r ref; do
            printf '%s\n' "${ref#issues/}" | cut -c1-7
        done
}

# ---------------------------------------------------------------------------
# Helper: list configured git remotes
# ---------------------------------------------------------------------------
__git_issue_remotes() {
    git remote 2>/dev/null
}

# ---------------------------------------------------------------------------
# Main completion function for "git issue" (invoked as "git-issue" or via
# git's completion dispatch as "_git_issue").
# ---------------------------------------------------------------------------
_git_issue() {
    local cur prev words cword
    if declare -f _init_completion >/dev/null 2>&1; then
        _init_completion || return
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
    fi

    # All subcommands
    local subcommands="create ls show comment edit state search import export sync merge fsck init version"

    # Determine the subcommand, skipping "git" and "issue" tokens.
    local subcmd=""
    local subcmd_idx=0
    local i
    for (( i=0; i < cword; i++ )); do
        case "${words[i]}" in
            git|issue|git-issue) continue ;;
        esac
        # Check if token is a known subcommand
        local w
        for w in $subcommands; do
            if [[ "${words[i]}" == "$w" ]]; then
                subcmd="$w"
                subcmd_idx=$i
                break 2
            fi
        done
    done

    # -------------------------------------------------------------------
    # No subcommand yet: complete subcommand names + top-level flags
    # -------------------------------------------------------------------
    if [[ -z "$subcmd" ]]; then
        COMPREPLY=( $(compgen -W "$subcommands --help --version -v -h" -- "$cur") )
        return
    fi

    # -------------------------------------------------------------------
    # Per-subcommand completion
    # -------------------------------------------------------------------
    case "$subcmd" in

        # ---------------------------------------------------------------
        # create
        # ---------------------------------------------------------------
        create)
            case "$prev" in
                -m|--message)   return ;;  # free-form text
                -l|--label)     return ;;  # free-form text
                -a|--assignee)  return ;;  # free-form text
                -p|--priority)
                    COMPREPLY=( $(compgen -W "low medium high critical" -- "$cur") )
                    return
                    ;;
                --milestone)    return ;;  # free-form text
            esac
            COMPREPLY=( $(compgen -W "-m --message -l --label -a --assignee -p --priority --milestone -h --help" -- "$cur") )
            ;;

        # ---------------------------------------------------------------
        # ls
        # ---------------------------------------------------------------
        ls)
            case "$prev" in
                -s|--state)
                    COMPREPLY=( $(compgen -W "open closed all" -- "$cur") )
                    return
                    ;;
                -l|--label)     return ;;
                --assignee)     return ;;
                --priority)
                    COMPREPLY=( $(compgen -W "low medium high critical" -- "$cur") )
                    return
                    ;;
                -f|--format)
                    COMPREPLY=( $(compgen -W "short full oneline" -- "$cur") )
                    return
                    ;;
                --sort)
                    COMPREPLY=( $(compgen -W "created updated priority state" -- "$cur") )
                    return
                    ;;
            esac
            COMPREPLY=( $(compgen -W "-s --state -l --label --assignee --priority -a --all -f --format --sort --reverse -h --help" -- "$cur") )
            ;;

        # ---------------------------------------------------------------
        # show
        # ---------------------------------------------------------------
        show)
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W "-h --help" -- "$cur") )
                    ;;
                *)
                    COMPREPLY=( $(compgen -W "$(__git_issue_ids)" -- "$cur") )
                    ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # comment
        # ---------------------------------------------------------------
        comment)
            case "$prev" in
                -m|--message)   return ;;
            esac
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W "-m --message -h --help" -- "$cur") )
                    ;;
                *)
                    COMPREPLY=( $(compgen -W "$(__git_issue_ids)" -- "$cur") )
                    ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # edit
        # ---------------------------------------------------------------
        edit)
            case "$prev" in
                -t|--title)         return ;;
                -l|--label)         return ;;
                --add-label)        return ;;
                --remove-label)     return ;;
                -a|--assignee)      return ;;
                -p|--priority)
                    COMPREPLY=( $(compgen -W "low medium high critical" -- "$cur") )
                    return
                    ;;
                --milestone)        return ;;
                -m|--message)       return ;;
            esac
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W "-t --title -l --label --add-label --remove-label -a --assignee -p --priority --milestone -m --message -h --help" -- "$cur") )
                    ;;
                *)
                    COMPREPLY=( $(compgen -W "$(__git_issue_ids)" -- "$cur") )
                    ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # state
        # ---------------------------------------------------------------
        state)
            case "$prev" in
                --state)
                    # Custom state value -- no fixed completions, but offer common ones
                    COMPREPLY=( $(compgen -W "open closed" -- "$cur") )
                    return
                    ;;
                -m|--message)   return ;;
                --fixed-by)     return ;;
                --release)      return ;;
                --reason)
                    COMPREPLY=( $(compgen -W "duplicate wontfix invalid completed" -- "$cur") )
                    return
                    ;;
            esac
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W "--open --close --state -m --message --fixed-by --release --reason -h --help" -- "$cur") )
                    ;;
                *)
                    COMPREPLY=( $(compgen -W "$(__git_issue_ids)" -- "$cur") )
                    ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # search
        # ---------------------------------------------------------------
        search)
            case "$prev" in
                -s|--state)
                    COMPREPLY=( $(compgen -W "open closed all" -- "$cur") )
                    return
                    ;;
            esac
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W "-s --state -i --ignore-case -h --help" -- "$cur") )
                    ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # import
        # ---------------------------------------------------------------
        import)
            case "$prev" in
                --state)
                    COMPREPLY=( $(compgen -W "open closed all" -- "$cur") )
                    return
                    ;;
            esac
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W "--state --dry-run -h --help" -- "$cur") )
                    ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # export
        # ---------------------------------------------------------------
        export)
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W "--dry-run -h --help" -- "$cur") )
                    ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # sync
        # ---------------------------------------------------------------
        sync)
            case "$prev" in
                --state)
                    COMPREPLY=( $(compgen -W "open closed all" -- "$cur") )
                    return
                    ;;
            esac
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W "--state --dry-run -h --help" -- "$cur") )
                    ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # merge
        # ---------------------------------------------------------------
        merge)
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W "--check --no-fetch -h --help" -- "$cur") )
                    ;;
                *)
                    COMPREPLY=( $(compgen -W "$(__git_issue_remotes)" -- "$cur") )
                    ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # fsck
        # ---------------------------------------------------------------
        fsck)
            COMPREPLY=( $(compgen -W "--quiet -h --help" -- "$cur") )
            ;;

        # ---------------------------------------------------------------
        # init
        # ---------------------------------------------------------------
        init)
            case "$cur" in
                -*)
                    COMPREPLY=( $(compgen -W "-h --help" -- "$cur") )
                    ;;
                *)
                    COMPREPLY=( $(compgen -W "$(__git_issue_remotes)" -- "$cur") )
                    ;;
            esac
            ;;

        # ---------------------------------------------------------------
        # version (no completions needed)
        # ---------------------------------------------------------------
        version)
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Register completions
# ---------------------------------------------------------------------------

# Standalone "git-issue" command
complete -F _git_issue git-issue

# Integration with git's completion system.
# When git-completion.bash is loaded, git dispatches "git issue <TAB>" to a
# function named _git_issue (which we already defined above).
# If __git_complete is available, register through git's helper to get the
# full git wrapper (e.g. __gitcomp support, GIT_DIR awareness).
if declare -f __git_complete >/dev/null 2>&1; then
    __git_complete "git issue" _git_issue
fi
