#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
test_options=(--cache-path .build/cache --config-path .build/config --security-path .build/security --disable-xctest)
# Some Command Line Tools releases omit TestingMacros from Swift Build's
# resolved-plugin list. Load the bundled library explicitly when available.
compiler_path="$(xcrun --find swiftc)"
testing_plugin="${compiler_path:h:h}/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -f "$testing_plugin" ]]; then
    test_options+=(-Xswiftc -load-plugin-library -Xswiftc "$testing_plugin")
fi
swift test "${test_options[@]}" "$@"
