# SwiftLint Integration Guide

## Overview

SwiftLint is integrated into the iExpense project to maintain consistent Swift code style and catch common mistakes.

## Setup Instructions

### 1. Install SwiftLint via CocoaPods

```bash
cd /Users/dragomirmindrescu/Desktop/Projects/iExpense
pod install
```

### 2. Configuration

SwiftLint configuration is defined in `.swiftlint.yml`. This file includes:

- **Disabled Rules**: Rules that don't fit our project style
- **Opt-in Rules**: Additional rules we want to enforce
- **Analyzer Rules**: Static analysis rules
- **Thresholds**: Complexity and length limits

### 3. Running SwiftLint

#### From Command Line

Run SwiftLint on all Swift files:

```bash
swiftlint
```

Run SwiftLint on specific files:

```bash
swiftlint --path Sources/
```

Autocorrect fixable issues:

```bash
swiftlint --fix
```

#### In Xcode Build Process

To automatically run SwiftLint during builds:

1. Open the project in Xcode: `open Inpenso.xcodeproj`
2. Select the iExpense target
3. Go to Build Phases → + → New Run Script Phase
4. Paste the following:

```bash
if [ "${CONFIGURATION}" == "Debug" ]; then
    "${PODS_ROOT}/SwiftLint/swiftlint" --config .swiftlint.yml
fi
```

### 4. Configuration Files

#### `.swiftlint.yml`

Main configuration file that defines:

- Disabled rules
- Opt-in rules
- Analyzer rules
- Thresholds for complexity, line length, etc.
- Excluded paths

#### `Podfile`

Includes SwiftLint as a CocoaPods dependency for both:

- `iExpense` target
- `iExpenseWidgetExtension` target

#### `Scripts/swiftlint.sh`

Utility script for running SwiftLint in CI/CD pipelines or as a build phase.

## Rules Overview

### Disabled Rules

- `trailing_whitespace`: Allows trailing whitespace
- `line_length`: Warnings at 120 chars, errors at 200 chars
- `force_unwrapping`: Allows force unwrapping (use with caution)

### Opt-in Rules

- `implicit_return`: Prefer implicit returns in short closures
- `missing_docs`: Warns about undocumented public declarations
- `vertical_parameter_alignment_on_call`: Aligns function call parameters
- And many more...

### Analyzer Rules

- `explicit_self`: Require explicit `self` where applicable
- `unused_declaration`: Warns about unused code
- `unused_import`: Warns about unused imports

## Common Issues and Solutions

### Issue: SwiftLint binary not found

**Solution**: Install via Homebrew or CocoaPods:

```bash
brew install swiftlint
# or
pod install
```

### Issue: Rules are too strict

**Solution**: Modify thresholds or disable rules in `.swiftlint.yml`

### Issue: False positives on generated code

**Solution**: Add paths to `excluded` in `.swiftlint.yml`

## CI/CD Integration

SwiftLint can be integrated into CI/CD pipelines (GitHub Actions, GitLab CI, etc.):

```yaml
- name: Run SwiftLint
  run: |
    swiftlint --config .swiftlint.yml --strict
```

## Resources

- [SwiftLint GitHub Repository](https://github.com/realm/SwiftLint)
- [SwiftLint Rules](https://realm.io/docs/swift/latest/index.html)

## Team Guidelines

When contributing to iExpense:

1. Run `swiftlint --fix` before committing to auto-fix issues
2. Address remaining SwiftLint warnings and errors
3. Update `.swiftlint.yml` if adding new rules (team consensus required)
4. Never disable critical rules without discussion

---

**Last Updated**: May 3, 2026
