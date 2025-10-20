#!/usr/bin/env bash

set -e

basedir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "${basedir}/shard.yml" ]]; then
  echo 1>&2 "$0: ${basedir}/shard.yml: file not found"
  exit 1
fi

unset -v version
while read -r line; do
  if [[ "$line" =~ ^version:[\ ]*(.*)$ ]]; then
    version="${BASH_REMATCH[1]}"
  fi
done < "${basedir}/shard.yml"

if [[ -n "$version" ]]; then
  echo "$version"
else
  echo 1>&2 "$0: ${basedir}/shard.yml: could not find version in shard config"
  exit 1
fi

