#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
mkdir -p .build/module-cache
swiftc -parse-as-library -module-cache-path "$project_dir/.build/module-cache" \
    Sources/MacConsole/SystemMonitor.swift scripts/check-system-metrics.swift \
    -o .build/check-system-metrics
.build/check-system-metrics
