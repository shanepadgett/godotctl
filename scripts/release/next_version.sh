#!/usr/bin/env bash

set -euo pipefail

initial_version="0.0.0"
format="kv"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --initial-version)
      if [ "$#" -lt 2 ]; then
        echo "missing value for --initial-version" >&2
        exit 1
      fi
      initial_version="$2"
      shift 2
      ;;
    --json)
      format="json"
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if ! [[ "$initial_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "invalid --initial-version (expected X.Y.Z): $initial_version" >&2
  exit 1
fi

last_tag="$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)"
range="HEAD"
base_version="$initial_version"

if [ -n "$last_tag" ]; then
  range="${last_tag}..HEAD"
  base_version="${last_tag#v}"
fi

commit_list="$(git rev-list "$range")"
if [ -z "$commit_list" ]; then
  if [ -n "$last_tag" ]; then
    echo "no commits found since ${last_tag}" >&2
    exit 1
  fi
  echo "no commits found in repository" >&2
  exit 1
fi

bump="patch"
commit_count=0

while IFS= read -r sha; do
  [ -z "$sha" ] && continue

  subject="$(git show -s --format=%s "$sha")"
  body="$(git show -s --format=%b "$sha")"
  commit_count=$((commit_count + 1))

  if printf '%s\n' "$subject" | grep -Eq '^[A-Za-z0-9_-]+(\([^)]+\))?!:' || printf '%s\n' "$body" | grep -Eq 'BREAKING[[:space:]-]CHANGE:'; then
    bump="major"
    break
  fi

  if [ "$bump" != "minor" ] && printf '%s\n' "$subject" | grep -Eq '^feat(\([^)]+\))?:'; then
    bump="minor"
  fi
done <<<"$commit_list"

IFS='.' read -r major minor patch <<<"$base_version"

case "$bump" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
  *)
    echo "unexpected bump: $bump" >&2
    exit 1
    ;;
esac

next_version="${major}.${minor}.${patch}"
next_tag="v${next_version}"

if [ "$format" = "json" ]; then
  printf '{"previous_tag":"%s","base_version":"%s","bump":"%s","commits":%d,"next_version":"%s","next_tag":"%s"}\n' \
    "$last_tag" "$base_version" "$bump" "$commit_count" "$next_version" "$next_tag"
  exit 0
fi

printf 'PREVIOUS_TAG=%s\n' "$last_tag"
printf 'BASE_VERSION=%s\n' "$base_version"
printf 'BUMP=%s\n' "$bump"
printf 'COMMITS=%s\n' "$commit_count"
printf 'NEXT_VERSION=%s\n' "$next_version"
printf 'NEXT_TAG=%s\n' "$next_tag"
