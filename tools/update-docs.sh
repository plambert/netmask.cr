#!/usr/bin/env bash

# Update the gh-pages `docs/` directory with the given branch or tag's documentation.

set -e -o pipefail

# Determine the mode of operation

mode=-PUSH-
force=""

while [[ $# -gt 0 ]]; do
  opt="$1"
  shift
  case "$opt" in
    --force)
      force=-YES-
      ;;
    --no-force)
      force=""
      ;;
    --diff)
      mode=-DIFF-
      ;;
    --push)
      mode=-PUSH-
      ;;
    --dryrun)
      mode=-DRYRUN-
      ;;
    *)
      echo 1>&2 "$0: $opt: unknown option"
      exit 1
      ;;
  esac
done

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


if [[ ! -n "$force" ]]; then
  mapfile -t status_lines < <(git status --porcelain)

  if [[ "${#status_lines[*]}" -gt 0 ]]; then
    printf 1>&2 '\e[31m%s\e[0m\n' "${status_lines[@]}"
    echo 1>&2 "ERROR: current working directory is dirty, cannot continue"
    exit 1
  fi
fi

reftype=""
refname=""

if refname="$(git describe --tags --exact-match 2> /dev/null)"; then
  reftype=tag
elif refname="$(git rev-parse --abbrev-ref HEAD)" && [[ -n "$branch" ]]; then
  reftype=branch
fi

if [[ -z "$refname" ]] || [[ -z "$reftype" ]]; then
  refname="$(git rev-parse --short HEAD)"
  reftype="commit"
fi

timestamp="$(env TZ=UTC date +%Y-%m-%d\ %H:%M:%S)"

printf -v refname '%s %q (%s UTC)' "$reftype" "$refname" "$timestamp"

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

if type -p jq > /dev/null; then
  (
    cd "$WORKTREE_DIR"
    mv "docs/index.json" "./index.json"
    jq . "./index.json" > "docs/index.json"
    rm "./index.json"
    mv "docs/search-index.js" "./search-index.js"
    IFS='(' read -r callback_function _ < ./search-index.js
    if [[ -n "$callback_function" ]]; then
      echo "${callback_function}(" > tmp
      while read -r line; do
        echo "  $line" >> tmp
      done < docs/index.json 
      echo ")" >> tmp
      mv tmp docs/search-index.js
    fi
    rm -f ./search-index.js
  )
fi

case "$mode" in
  -DIFF-)
    git -C "$WORKTREE_DIR" diff
    ;;

  -PUSH-)
    git -C "$WORKTREE_DIR" commit -a -m "Commit new documentation for ${refname}"
    git -C "$WORKTREE_DIR" push
    git -C . fetch -a
    ;;

  -DRYRUN-)
    (cd "$WORKTREE_DIR" && find ./* -type f -ls)
    ;;

  *)
    echo 1>&2 "$0: ${mode}: unknown mode"
    exit 1
    ;;
esac

cleanup_at_exit
