#!/usr/bin/env bash

# Update the gh-pages `docs/` directory with the given branch or tag's documentation.

set -e -o pipefail

# Configure variables for needed literal values

GITHUB_PAGES_BRANCH=gh-pages
WORKTREE_NAME=generate-documentation

# Clean up when we exit

cleanup_at_exit() {
  if [[ -n "$tmpdir" ]]; then
    while read -r line; do
      if [[ "$line" =~ ^worktree\ \/.*\/"$WORKTREE_NAME"$ ]]; then
        git worktree remove -f "${line#worktree }" > /dev/null 2>&1 || true
      fi
    done < <(git worktree list --porcelain)
    rm -rf "$tmpdir" > /dev/null 2>&1
    unset -v tmpdir
  fi
}

trap cleanup_at_exit EXIT

# Create a temporary directory and make sure we delete it whenever possibe, if we exit
# for any unexpected reason.

tmpdir="$(mktemp -d)"

# Create a workspace for the docs in the temporary directory.

WORKTREE_DIR="${tmpdir}/${WORKTREE_NAME}"
mkdir -p "$WORKTREE_DIR"

git worktree add "$WORKTREE_DIR" "$GITHUB_PAGES_BRANCH"

(cd "$WORKTREE_DIR" && find . -type f -ls || true)

echo OK

cleanup_at_exit
