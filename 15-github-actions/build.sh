#!/usr/bin/env bash
# Packages the app into a versioned tarball in dist/, which the pipeline then
# uploads as an artifact. The version is the commit, so every build is traceable.
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${GITHUB_SHA:-local}"
VERSION="${VERSION:0:7}"
mkdir -p dist
tar -czf "dist/calculator-${VERSION}.tar.gz" app requirements.txt
{
  echo "name: calculator"
  echo "version: ${VERSION}"
  echo "built_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "built_by: ${GITHUB_ACTOR:-local}"
  echo "runner: ${RUNNER_OS:-local}"
} > dist/build-info.txt
echo "built dist/calculator-${VERSION}.tar.gz"
cat dist/build-info.txt
