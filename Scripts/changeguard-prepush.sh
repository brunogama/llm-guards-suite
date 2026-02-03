#!/usr/bin/env bash
set -euo pipefail

swift package change-guard -- --config .changeguard.json
