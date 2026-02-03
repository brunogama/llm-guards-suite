#!/usr/bin/env bash
set -euo pipefail

# Pre-push hook: enforce always (still cheap; only analyzes Tests/** diff and optional coverage).
swift package quality-guard -- --config .qualityguard.json
