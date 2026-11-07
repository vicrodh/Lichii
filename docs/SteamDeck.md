# Steam Deck LCD: Ocarina of Time

These builds target Steam Deck's Zen 2 CPU. Performance on the physical Deck is
not yet measured. Build metadata accompanies each artifact; it records the
compiler, source revision, CPU target, and PGO mode.

## Builds

The `Steam Deck Ocarina` workflow runs when build inputs change on the
`steam-deck-oot` branch. Once the workflow is also on the repository's default
branch, its manual mode selector offers:

| Mode | Artifacts | Purpose |
| --- | --- | --- |
| `compare` | generic Clang baseline and Zen 2 + ThinLTO | Measure the specialized build against the same compiler and source |
| `train` | instrumented Zen 2 build | Collect Linux PGO data during Ocarina gameplay |
| `pgo` | Zen 2 + ThinLTO, with and without the trained profile | Measure PGO against its unprofiled counterpart |

Artifacts contain an AppImage, checksums, build metadata, and PGO helpers.
Extract the tarball, make the AppImage executable, and add it as a non-Steam
game. These Ubuntu 24.04 packages require glibc 2.39 or newer; check with
`getconf GNU_LIBC_VERSION` on the Deck. Graphics drivers remain supplied by SteamOS.

For a local build with dependencies installed, use CMake 3.31+, Clang, lld,
Ninja, and Qt 6.8.3:

```sh
CC=clang CXX=clang++ bash tools/steam-deck/build.sh steam-deck \
  -DCMAKE_PREFIX_PATH=/path/to/Qt/6.8.3/gcc_64
```

`YUZU_BUILD_PRESET=zen2` selects `-march=znver2 -mtune=znver2`. Clang's CMake IPO
support enables ThinLTO. The baseline uses generic x86-64 and disables LTO.
Build parallelism defaults to two workers to control CI memory use. The
normal rendering, synchronization, and floating-point correctness settings
remain those of Lichii. The Linux Bluetooth Xbox fix is included.

## Initial Ocarina comparison

Use the same save, camera position, TDP, SteamOS version, and shader-cache state
for each comparison. Measure a cold-cache run separately from steady gameplay.
Record game FPS, frame-time spikes, RAM usage, and APU power. Treat graphics
completeness, game speed, and audio synchronization as part of the result.

Start with Vulkan, handheld mode, 1x scale, BC3 texture recompression,
conservative VRAM, and CPU Clock Normal. For this game's Add-Ons, disable
`Max Resolution` during the comparison: it disables the game's dynamic
resolution controller. Keep the Dynamic FPS add-on consistent between runs.
Its timing assumes a normal, unscaled guest counter.

Ship and retain `nx2_switches.txt`. Its split-GPU and fence batching defaults
are already enabled; Ocarina selects its own frames-ahead behavior. The
12 GiB guest memory layout uses sparse backing and is not an immediate
12 GiB resident allocation. Measure actual memory use on the 16 GiB Deck.
Check the log for unsupported mesh shaders if geometry is missing; a faster
frame rate with incomplete rendering does not establish an optimization.

## Lossless Scaling

LSFG is compiled into the Vulkan renderer on Linux. Put `Lossless.dll` from
your installed Steam copy of Lossless Scaling in:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/eden/lossless/Lossless.dll
```

The library and its shaders are loaded locally by Lichii. Build artifacts
contain the emulator and its open-source dependencies. Keep the library in
the user directory when replacing an AppImage.

First measure with frame generation disabled. If game FPS is stable near
30 with GPU headroom, compare the built-in LSFG performance mode at 2x on
the LCD's 60 Hz display. Record both game FPS and displayed/generated FPS,
plus input latency. Use one frame-generation path at a time when comparing
built-in LSFG with an external lsfg-vk installation.

## Train Ocarina PGO on Linux

CI uses LLVM 22 for every variant. The existing `lichii-windows.profdata`
uses the Windows ABI and cannot be used for this Linux build.

1. Build/download the `train` variant and extract its tarball.
2. Run the training AppImage through the supplied helper:

   ```sh
   bash train-pgo.sh ./lichii-steam-deck-train-x86_64.AppImage \
     -f -g "/path/to/Ocarina.nup"
   ```

3. Play representative scenes: menus, indoor/outdoor areas, camera movement,
   combat, and loading transitions. Exit Lichii normally to flush counters.
   Raw profiles are in `~/.local/state/lichii/steam-deck-oot-pgo` unless
   `XDG_STATE_HOME` or `LICHII_PGO_DIR` selects another location.
4. Copy the raw profiles to a machine with LLVM 22 and merge them:

   ```sh
   LLVM_PROFDATA=llvm-profdata-22 bash merge-pgo.sh \
     /path/to/raw-profiles /path/to/Lichii/steam-deck-oot.profdata
   ```

5. Build `steam-deck-pgo` locally or commit that Linux profile and run the
   workflow's `pgo` mode. Preserve the recorded training compiler/source
   revision alongside the profile. Compare against the unprofiled build
   before adopting it; training instrumentation is not a performance build.

The game is used locally for training and benchmarking. A profile contains
host compiler execution counts; the workflow builds without a game archive.
