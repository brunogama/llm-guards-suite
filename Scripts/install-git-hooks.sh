#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$(git rev-parse --git-path hooks)"

mkdir -p "${HOOKS_DIR}"

# pre-commit: fast guards (heuristic triggers inside scripts)
cat > "${HOOKS_DIR}/pre-commit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Run fast-triggered guards (they exit fast when irrelevant)
Scripts/apiguard-precommit.sh
Scripts/qualityguard-precommit.sh
EOF
chmod +x "${HOOKS_DIR}/pre-commit"

# pre-push: enforce minimal diff + test guard
cat > "${HOOKS_DIR}/pre-push" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

Scripts/qualityguard-prepush.sh
Scripts/changeguard-prepush.sh
EOF
chmod +x "${HOOKS_DIR}/pre-push"

echo "Installed git hooks:"
echo "  ${HOOKS_DIR}/pre-commit"
echo "  ${HOOKS_DIR}/pre-push"
