#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
preset=${1:-steam-deck}
if (($#)); then shift; fi
case "$preset" in
  steam-deck|steam-deck-baseline|steam-deck-train|steam-deck-pgo) ;;
  *) echo "Unknown Steam Deck preset: $preset" >&2; exit 2 ;;
esac

export CC=${CC:-clang}
export CXX=${CXX:-clang++}
if ! "$CXX" --version | head -n 1 | grep -qi clang; then
  echo 'Steam Deck presets require Clang and lld.' >&2
  exit 2
fi
if [[ "$preset" == steam-deck-pgo && ! -s "$root/steam-deck-oot.profdata" ]]; then
  echo 'Collect and merge Linux Ocarina training data into steam-deck-oot.profdata first.' >&2
  exit 2
fi

cd "$root"
cmake --preset "$preset" "$@"
cmake --build "build/$preset" --target yuzu yuzu-cmd \
  --parallel "${CMAKE_BUILD_PARALLEL_LEVEL:-2}"

python3 - "$preset" "$CXX" <<'PY'
import hashlib
import json
from pathlib import Path
import subprocess
import sys

preset, compiler = sys.argv[1:]
profile = Path('steam-deck-oot.profdata')
metadata = {
    'preset': preset,
    'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'compiler': subprocess.check_output([compiler, '--version'], text=True).splitlines()[0],
    'cpu': 'generic x86-64' if preset.endswith('baseline') else 'AMD Zen 2 (znver2)',
    'lto': 'off' if preset.endswith('baseline') else 'ThinLTO',
    'pgo': 'instrumented' if preset.endswith('train') else 'use' if preset.endswith('pgo') else 'off',
    'profile_sha256': hashlib.sha256(profile.read_bytes()).hexdigest() if preset.endswith('pgo') else None,
    'gameplay_tested': False,
}
Path(f'build/{preset}/build-info.json').write_text(json.dumps(metadata, indent=2) + '\n')
PY
