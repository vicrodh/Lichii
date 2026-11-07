#!/usr/bin/env bash
set -euo pipefail
if (($# != 2)); then
  echo "Usage: $0 /directory/with/profraw /path/to/steam-deck-oot.profdata" >&2
  exit 2
fi
profile_dir=$1
output=$2
profdata=${LLVM_PROFDATA:-llvm-profdata-22}
if ! command -v "$profdata" >/dev/null; then
  echo 'Set LLVM_PROFDATA to llvm-profdata from the same LLVM major used for training (CI: 22).' >&2
  exit 2
fi
shopt -s nullglob
profiles=("$profile_dir"/*.profraw)
if ((${#profiles[@]} == 0)); then
  echo "No .profraw files found in $profile_dir" >&2
  exit 2
fi
"$profdata" merge -o "$output" "${profiles[@]}"
"$profdata" show "$output"
echo "Merged Ocarina Linux profile: $output"
