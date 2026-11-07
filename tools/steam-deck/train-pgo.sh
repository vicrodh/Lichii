#!/usr/bin/env bash
set -euo pipefail
if (($# == 0)); then
  echo "Usage: $0 /path/to/lichii-steam-deck-train-x86_64.AppImage [Lichii arguments...]" >&2
  exit 2
fi
executable=$1
shift
if [[ ! -x "$executable" ]]; then
  echo "Training AppImage is not executable: $executable" >&2
  exit 2
fi
profile_dir=${LICHII_PGO_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/lichii/steam-deck-oot-pgo}
mkdir -p "$profile_dir"
profile_dir=$(cd -- "$profile_dir" && pwd)
export LLVM_PROFILE_FILE="$profile_dir/lichii-%m-%p.profraw"
echo "Training profiles: $profile_dir"
echo 'Use the instrumented training build, play representative scenes, then exit normally.'
exec "$executable" "$@"
