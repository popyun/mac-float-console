#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
mkdir -p .build/module-cache
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/module-cache"
export SWIFT_MODULECACHE_PATH="$project_dir/.build/module-cache"
swiftc -parse-as-library -module-cache-path "$project_dir/.build/module-cache" \
    Sources/MacConsole/CodexUsage.swift Sources/MacConsole/SystemMonitor.swift \
    Sources/MacConsole/PreviewModel.swift Sources/MacConsole/ConsoleView.swift \
    scripts/export-previews.swift -o .build/export-previews
.build/export-previews "$project_dir/artifacts" "${1:-}"
