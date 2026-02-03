#!/usr/bin/env bash
set -euo pipefail

# Fast heuristic: only run API guard if staged diff touches 'public' or 'open' tokens.
# This keeps the hook cheap in huge repos.

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

DIFF="$(git diff --cached -U0 -- '*.swift' 'Package.swift' || true)"

if ! echo "${DIFF}" | grep -E '^[+-].*\b(public|open)\b' >/dev/null 2>&1; then
  exit 0
fi

# Run the real gate
swift package api-guard -- --config .apiguard.json
