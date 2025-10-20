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

# git describe --tags --exact-match 2> /dev/null \
# || git rev-parse --short HEAD
# Identify if we are on a tag, or on a committed branch

mapfile -t status_lines < <(git status --porcelain)

if [[ "${#status_lines[*]}" -gt 0 ]]; then
  printf 1>&2 '\e[31m%s\e[0m\n' "${status_lines[@]}"
  echo 1>&2 "ERROR: current working directory is dirty, cannot continue"
  exit 1
fi

refname=""
if tag="$(git describe --tags --exact-match 2> /dev/null)"; then
  refname="tag-${tag}"
elif branch="$(git rev-parse --abbrev-ref HEAD)" && [[ -n "$branch" ]]; then
  refname="$branch"
fi

if [[ -z "$refname" ]]; then
  refname="commit-$(git rev-parse --short HEAD)"
fi

# Create a workspace for the docs in the temporary directory.

WORKTREE_DIR="${tmpdir}/${WORKTREE_NAME}"
mkdir -p "$WORKTREE_DIR"

git worktree add "$WORKTREE_DIR" "$GITHUB_PAGES_BRANCH"

# Create the docs into the docs directory in that branch

crystal docs \
  --project-name=netmask.cr \
  --project-version=main-branch \
  --source-refname="$refname" \
  --source-url-pattern="https://plambert.github.io/netmask.cr/" \
  --output "${WORKTREE_DIR}/docs" \
  --format html \
  --canonical-base-url="https://plambert.github.io/netmask.cr/" \
  --error-trace \
  --stats \
  --time \
  --error-on-warnings

git -C "$WORKTREE_DIR" commit -a -m "Commit new documentation for ${refname}"

git -C "$WORKTREE_DIR" push

cd "$WORKTREE_DIR" && find * -type f -ls

echo OK

cleanup_at_exit
