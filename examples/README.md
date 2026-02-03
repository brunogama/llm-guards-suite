# Example Configurations

This directory contains example configuration files for different use cases.

## QualityGuard Examples

| File | Description |
|------|-------------|
| `qualityguard-zero-tolerance.json` | Strict mode - no test deletions allowed |
| `qualityguard-with-coverage.json` | With coverage tracking enabled |

## ChangeGuard Examples

| File | Description |
|------|-------------|
| `changeguard-strict.json` | Small PRs (5 files, 200 lines max) |
| `changeguard-lenient.json` | Feature branches (25 files, 1000 lines max) |

## APIGuard Examples

| File | Description |
|------|-------------|
| `apiguard-semver.json` | Semver mode - additions allowed |
| `apiguard-strict.json` | Strict mode - no changes allowed |

## Usage

Copy the example to your project root and rename:

```bash
cp examples/qualityguard-zero-tolerance.json .qualityguard.json
cp examples/changeguard-strict.json .changeguard.json
cp examples/apiguard-semver.json .apiguard.json
```

Then modify the configuration to match your project:

```bash
# Edit targets in APIGuard config
sed -i '' 's/MyPublicLibrary/YourActualTarget/g' .apiguard.json
```
