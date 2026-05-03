#!/bin/bash

# SwiftLint build phase script
# This script runs SwiftLint on all Swift files in the project

if [ "${CONFIGURATION}" == "Debug" ]; then
    SWIFTLINT_PATH="${PODS_ROOT}/SwiftLint/swiftlint"
    
    if [ -f "$SWIFTLINT_PATH" ]; then
        echo "Running SwiftLint..."
        "$SWIFTLINT_PATH" --config .swiftlint.yml
    else
        # Fallback to system SwiftLint if not installed via CocoaPods
        if which swiftlint > /dev/null; then
            echo "Running SwiftLint (system)..."
            swiftlint --config .swiftlint.yml
        else
            echo "warning: SwiftLint not found. Please install it: brew install swiftlint"
        fi
    fi
fi
