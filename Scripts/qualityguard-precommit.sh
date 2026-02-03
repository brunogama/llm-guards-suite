#!/usr/bin/env bash
set -euo pipefail

# Fast heuristic hook:
# Runs QualityGuard only if staged changes touch Tests/** or delete/modify test funcs.

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

STAGED="$(git diff --cached --name-only -- 'Tests/**' || true)"
if [[ -z "${STAGED}" ]]; then
  # Also run if staged diff removes a 'func test'
  DIFF="$(git diff --cached -U0 -- 'Tests/**' || true)"
  if ! echo "${DIFF}" | grep -E '^-.*\bfunc\s+test[A-Za-z0-9_]+' >/dev/null 2>&1; then
    exit 0
  fi
fi

swift package quality-guard -- --config .qualityguard.json
