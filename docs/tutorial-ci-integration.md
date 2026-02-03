# Tutorial: CI Integration

This tutorial covers advanced CI/CD integration patterns for LLM Guards Suite.

## GitHub Actions

### Basic Setup

```yaml
# .github/workflows/guards.yml
name: Guards

on:
  pull_request:
  push:
    branches: [main]

jobs:
  guard:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Select base range
        id: range
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            echo "RANGE=origin/${{ github.base_ref }}...HEAD" >> $GITHUB_OUTPUT
          else
            echo "RANGE=origin/main...HEAD" >> $GITHUB_OUTPUT
          fi

      - name: ChangeGuard
        run: swift package change-guard -- --range "${{ steps.range.outputs.RANGE }}"

      - name: QualityGuard
        run: swift package quality-guard -- --range "${{ steps.range.outputs.RANGE }}"

      - name: APIGuard
        run: swift package api-guard
```

### Parallel Execution

For faster CI, run guards in parallel:

```yaml
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Build
        run: swift build

  quality-guard:
    runs-on: macos-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: QualityGuard
        run: swift package quality-guard

  change-guard:
    runs-on: macos-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: ChangeGuard
        run: swift package change-guard

  api-guard:
    runs-on: macos-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: APIGuard
        run: swift package api-guard
```

### Conditional Execution

Skip guards when not needed:

```yaml
jobs:
  quality-guard:
    runs-on: macos-latest
    if: contains(github.event.pull_request.labels.*.name, 'skip-guards') == false
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # Only run if Tests/ changed
      - name: Check for test changes
        id: test-changes
        run: |
          if git diff --name-only origin/${{ github.base_ref }}...HEAD | grep -q "^Tests/"; then
            echo "changed=true" >> $GITHUB_OUTPUT
          else
            echo "changed=false" >> $GITHUB_OUTPUT
          fi

      - name: QualityGuard
        if: steps.test-changes.outputs.changed == 'true'
        run: swift package quality-guard
```

### Required Status Checks

Configure branch protection rules to require guards:

1. Go to Repository Settings > Branches
2. Add branch protection rule for `main`
3. Enable "Require status checks to pass"
4. Select the guard jobs as required

## GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - build
  - guard

build:
  stage: build
  image: swiftlang/swift:nightly-6.0-jammy
  script:
    - swift build

quality-guard:
  stage: guard
  image: swiftlang/swift:nightly-6.0-jammy
  script:
    - swift package quality-guard
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

change-guard:
  stage: guard
  image: swiftlang/swift:nightly-6.0-jammy
  script:
    - swift package change-guard
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

api-guard:
  stage: guard
  image: swiftlang/swift:nightly-6.0-jammy
  script:
    - swift package api-guard
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
```

## Bitbucket Pipelines

```yaml
# bitbucket-pipelines.yml
image: swiftlang/swift:nightly-6.0-jammy

pipelines:
  pull-requests:
    '**':
      - step:
          name: Build
          script:
            - swift build
      - parallel:
          - step:
              name: QualityGuard
              script:
                - swift package quality-guard
          - step:
              name: ChangeGuard
              script:
                - swift package change-guard
          - step:
              name: APIGuard
              script:
                - swift package api-guard
```

## Bypass in CI

For emergency fixes, set the bypass environment variable:

```yaml
- name: QualityGuard (with bypass)
  env:
    ALLOW_TEST_DELETIONS: ${{ github.event.inputs.bypass_quality_guard }}
  run: swift package quality-guard
```

## Reporting

### Annotations

Add annotations for failed checks:

```yaml
- name: QualityGuard
  id: quality-guard
  continue-on-error: true
  run: |
    OUTPUT=$(swift package quality-guard 2>&1) || true
    echo "$OUTPUT"
    if echo "$OUTPUT" | grep -q "FAIL"; then
      echo "::error::QualityGuard detected test deletions"
      exit 1
    fi
```

### PR Comments

Use actions like `peter-evans/create-or-update-comment` to post results:

```yaml
- name: Post QualityGuard Results
  if: failure()
  uses: peter-evans/create-or-update-comment@v3
  with:
    issue-number: ${{ github.event.pull_request.number }}
    body: |
      ## QualityGuard Failed

      Test deletions were detected. Please review:
      - Ensure tests weren't accidentally removed
      - If intentional, set `ALLOW_TEST_DELETIONS=1`
```

## Caching

Speed up CI with caching:

```yaml
- name: Cache Swift Build
  uses: actions/cache@v4
  with:
    path: .build
    key: ${{ runner.os }}-swift-${{ hashFiles('Package.resolved') }}
    restore-keys: |
      ${{ runner.os }}-swift-
```
