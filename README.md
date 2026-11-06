<!--
# SPDX-FileCopyrightText: Copyright 2025 Eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

# SPDX-FileCopyrightText: 2018 yuzu Emulator Project
# SPDX-License-Identifier: GPL-2.0-or-later
-->

# Touqi

**Touqi** is an experimental, open-source Nintendo Switch 2 emulator fork focused on
performance research, reproducible benchmarking and open documentation.

It is based on [Lichii](https://github.com/zortos293/Lichii) (build-88), which builds on
[Eglantine](https://github.com/Djihads80/Eglantine), started by Camille LaVey, which in turn
builds on Eden, yuzu and Sudachi.

> **Status: experimental.** Compatibility, performance and stability vary by game, hardware and
> configuration. Today's work targets one game (The Legend of Zelda: Ocarina of Time) on one PC
> (Ryzen 5 7600X + RTX 5070). Touqi is not affiliated with Nintendo or endorsed by its upstream
> projects.

## Goals

1. **Performance, measured.** Find where frame time goes (CPU threads, Vulkan submission and
   waits, GPU) and change only what a measurement says matters. A change is kept only if it is
   faster *and* the image and gameplay stay correct.
2. **Reproducible benchmarking.** The same recorded controller input (TAS) replayed on every
   build, with frame-time percentiles (P50/P95/P99), not just average FPS.
3. **Open development.** Every experiment is written down, including the ones that failed.

## Benchmark pipeline

One command per build or option (`make bench` in [tools/oot-bench](tools/oot-bench/README.md)):

1. **Launch** the build with the debug server and per-frame logging, closing anything running.
2. **Boot to gameplay** automatically (presses A until the save loads).
3. **Replay** a recorded controller route (TAS) frame by frame through the debug server.
4. **Measure** every presented frame (P50/P95/P99, frames over 33 ms), GPU-thread zones and
   drains, and log events around each spike.
5. **Explain** each spike (pipeline builds, CPU reads of GPU memory, ASTC decodes) and **compare**
   runs, options and builds in one table (`make drops`, `make report`, `make compare`).

Every run keeps its config, logs, screenshots and per-frame data, so results can be checked
later. Methodology: [docs/benchmarks/methodology.md](docs/benchmarks/methodology.md).

## Where things stand (6 Nov 2026)

Ocarina of Time, Kokiri Forest route, 1x, Vulkan, 3 runs:

| Metric | Value |
| --- | --- |
| Average FPS | 36-38 |
| P50 / P95 / P99 frame time | ~24 / ~34 / 41-48 ms |
| Host GPU busy | ~35-41 % |

With the "Accurate" GPU mode some guides recommend, the emulator stops the GPU thread split and
both Lichii build-88 and Touqi drop to ~24-25 FPS on this PC; keep GPU accuracy Fast. See
[the results](docs/benchmarks/results/2026-11-06-oot-kokiri.md).

The GPU is mostly idle: the limit is the emulator's GPU-command threads, which wait on each other
because the game writes part of its own command lists on the GPU. No change so far has moved FPS
beyond run-to-run noise. Details, every experiment and the open problems:
[tools/oot-bench/HANDOFF.md](tools/oot-bench/HANDOFF.md).

## What Touqi adds on top of Lichii build-88

| Addition | Where |
| --- | --- |
| Lichii PRs #243, #250, #178 merged (OoT front-thread work) | `src/video_core/engines/maxwell_3d.*`, `query_cache`, ... |
| Automated TAS benchmark: boot, load save, replay, report percentiles and spike causes | [tools/oot-bench](tools/oot-bench/README.md) |
| `EDEN_NX2_FRAME_LOG=<file>`: per-present frame/fence/composite/pacing times (diagnostic) | `src/core/hle/service/nx2_gsv.h` |
| `EDEN_NX2_FAST_ACQUIRE=1`: answer semaphore acquires from known queued releases (experiment, off by default, verified correct) | `src/video_core/engines/puller.cpp` |
| Benchmark methodology and results | [docs/benchmarks](docs/benchmarks/README.md) |
| Optimization log and upstream sync notes | [docs/development](docs/development/optimization-log.md) |

## Building

Touqi uses Lichii's build system. General guide: [docs/Build.md](docs/Build.md). The exact
Windows setup used here (MSVC Build Tools, Qt 6.8.3, CMake, Ninja) and a one-command build script:
[tools/oot-bench/HANDOFF.md](tools/oot-bench/HANDOFF.md#how-to-work-on-it).

Only use games, keys and firmware you have legally obtained. None are included.

## Upstream and acknowledgements

Touqi would not exist without:

- [Lichii](https://github.com/zortos293/Lichii) by zortos293 and contributors: the direct base,
  including the debug server, profiler and OoT work this fork measures with.
- [Frizti/Lichii](https://github.com/Frizti/Lichii): OoT fixes integrated into Lichii.
- [Eglantine](https://github.com/Djihads80/Eglantine), started by Camille LaVey.
- Eden, yuzu, Sudachi and everyone who contributed to them.

Code ported from other forks keeps its authors' credit. Internal names (Eden/Eglantine/Lichii in
paths, settings and data folders) are kept on purpose, so upstream changes keep merging cleanly.

## License

Touqi keeps the open-source licenses and copyright notices inherited from upstream. See
[LICENSE.txt](LICENSE.txt), [LICENSES](LICENSES) and the headers in each source file.
