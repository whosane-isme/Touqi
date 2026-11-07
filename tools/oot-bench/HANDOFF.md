# OoT on an RTX 5070 PC: status and handoff (branch `oot-5070`)

> The fork is now presented as **Touqi** (see the root `README.md`); internal names stay
> Eden/Eglantine/Lichii so upstream keeps merging. Frame-time percentiles are now measured
> per run (`EDEN_NX2_FRAME_LOG`): baseline P50 ~24 ms, P95 33-35 ms, P99 41-48 ms on the route.
> Benchmark docs: `docs/benchmarks/`; optimization index: `docs/development/optimization-log.md`.
>
> **Assessment (6 Nov 2026):** a stable 60 FPS needs P50 cut ~30 % and P99 ~60 %. Everything
> cheap is already in the build; what remains (deferring GPU-written command lists, multi-threaded
> Vulkan recording) is a large, uncertain effort. Deep work is paused. Recommended mode: benchmark
> each new Lichii/Eglantine build with `make compare`, and contribute measurements upstream.
>
> **Upstream contribution candidates (the owner submits; agents never push or open PRs):**
> 1. `EDEN_NX2_FRAME_LOG` as a small diagnostic PR to zortos293/Lichii (`nx2_gsv.h` only).
> 2. Results on Lichii PRs #243, #250, #178: no gain on the 7600X/5070 Kokiri route
>    (36.4 vs ~36 FPS), with the measurement method.
> 3. `EDEN_NX2_FAST_ACQUIRE` as a discussion, not a PR: correct but not yet faster.

Start here. Last updated 6 November 2026. Written by an AI agent (Claude) working with the fork
owner; every number below was measured on the owner's PC with the tools in this folder unless it
says otherwise. Chronological details: `WORKLOG.md`. Plans: `ROADMAP-BOTTLENECK.md`,
`ROADMAP-5070.md`. Background reading: `GPU-OFFLOAD-NOTES.md`. Earlier fork comparison:
`docs/notes/OOT-RTX5070-FINDINGS.md`.

## Goal

Stable 60 FPS in The Legend of Zelda: Ocarina of Time (Switch 2, program `0400486024DEC000`,
v131072) without visual regressions, on the owner's PC:

| | |
| --- | --- |
| CPU | AMD Ryzen 5 7600X (6 cores / 12 threads) |
| GPU | NVIDIA GeForce RTX 5070 12 GB, driver 610.88 |
| RAM | 32 GB |
| OS | Windows 11 Pro |

## Where things are now

- **Branch `oot-5070`** = zortos293/Lichii build-88 (`55532f2`) + Lichii PRs #243, #250, #178
  (merged, one hand-resolved conflict in `maxwell_3d.{h,cpp}`) + tools and docs + one experiment
  switch (`EDEN_NX2_FAST_ACQUIRE`, off by default).
- **Why Lichii build-88 as the base:** best image on this PC, includes Frizti's OoT performance
  ports and Dark's Dynamic FPS mod. Compared on this PC: Frizti v2 (~31 FPS walking), Selevet
  build 8 (~31-39, it ran at half resolution), Lichii build 83 (long stalls). Lichii is itself a
  fork of Djihads80/Eglantine (163 commits ahead at build-88), so fixes meant for Eglantine
  upstream must be ported to Eglantine's `nx2`; the owner's original `nx2` branch is untouched.
- **FPS on the benchmark route (Kokiri Forest walk, 1x, Vulkan, Docked, GPU accuracy Fast):**
  ~36 FPS average with frequent dips; steady 60 only on light stretches. Settings changes, the
  three Lichii PRs and the fast-acquire experiment all land within run-to-run noise (33-39 FPS).
- **No real FPS gain has been achieved yet.** The tooling and the diagnosis are the progress.

## What we struggle with (read before starting)

1. **The GPU only reaches ~35-41 % use (62-82 W of 250 W).** The RTX 5070 waits for the emulator.
   Raising resolution does not use the idle GPU for free: 2x + SMAA dropped the route from 36.4
   to 30.9 FPS, because upload/copy work at higher resolution also lands on the CPU, and the
   built-in Max Resolution patch already raises internal resolution. DLSS upscaling cannot raise
   FPS here for the same reason. Frame generation (FSR3/LSFG, in the settings) multiplies
   displayed frames but cannot remove hitches and our benchmark cannot measure it (it counts
   guest presents only).
2. **The limit is CPU-side latency, a serial chain, not raw CPU or GPU throughput.**
   The emulator's GPU command processing is split: a *front* thread parses the game's command
   lists and macros, a *back* thread records Vulkan work. Measured per second while walking:
   - Front: ~400 ms waiting for the back (`split drain`), ~270 ms waiting for GPU-written lists
     (`list writers`, ~6,500-9,000 waits/s), ~300 ms on semaphore acquires; real work ~190 ms.
   - Back: ~71 % real work, ~21 % idle waiting for the front, ~8 % waiting for the GPU to go
     fully idle (`Scheduler::Finish` from guest CPU readbacks, ~200/s).
   - So the two threads mostly run in lockstep: front waits for back, back waits for front, and
     both wait for the GPU. OoT renders ~1,900 draws per frame (~70k draws/s, ~4.2M register
     writes/s) and **writes some of its own command lists and draw parameters on the GPU**
     (compute), which the CPU front must wait for before it can parse them. That is the knot.
3. **Removing one wait moves it to the next one.** `EDEN_NX2_FAST_ACQUIRE` removed acquire drains
   for known releases (verified: 0 wrong decisions in 32,768 checked) but list-writer waits rose
   from ~6,500 to ~9,000/s and FPS stayed within noise. Turning off reactive flushing or read
   traps (no CPU readbacks at all) also gained only ~1-2 FPS. Eglantine issue #681 (Mario Kart
   World) found exactly the same pattern.
4. **Measurement noise is large.** The same build on the same route varies 33-39 FPS between
   runs. Compare only with >= 3 runs per option, or with an in-run A/B toggle.
5. **The profiler's function names are partly wrong.** The in-process sampler (`sample`
   debug-server method) misattributes anonymous lambdas to the nearest named symbol (e.g.
   `FixedPipelineState::UnpackStencilOp` shows up as the 31 % caller of descriptor code, and
   `FmtLogMessage` under `KeplerCompute::ProcessNativeMethod`). Relinking with `/OPT:REF,NOICF`
   (temporary edit of `src/CMakeLists.txt:150`, never commit it) removes folding but not this.
   Trust consistent call chains and the zone profiler (`EDEN_NX2_GPU_PROFILE=1`) over single
   names.
6. **The three Lichii PRs did not help on this PC/route** (36.4 FPS vs ~36). Their authors
   measured ~52 -> 58-59 FPS at a Kokiri spot on an RTX 4090 + i9-13900K. Unknown whether the
   difference is the spot, the CPU, or settings.
7. **Environment limits on this PC:**
   - Building with 10 jobs while the game runs exhausts memory (`C1060 out of heap space`): set
     `JOBS=4` or close the game.
   - Lowering process priority (`start /LOW`) and running newly downloaded tools (PresentMon)
     were blocked by the agent's sandbox. The owner can allow them.
   - The fork's rule forbids agents from pushing; the owner pushes.
   - One emulator at a time: each needs ~14 GB.

## How to work on it

Everything runs from `tools/oot-bench` with GNU make + Windows PowerShell:

| Command | Purpose |
| --- | --- |
| `make bench LABEL=x N=3 INSTALL=<build folder> ENV="A=1;B=2" SET="ini_key=value"` | Fresh launch, auto-load the save, replay the owner's recorded walk, report FPS and spikes with causes |
| `make drops` | Explain each spike of the latest run from the emulator log |
| `make report` | One line per run (build, options, avg FPS, ~1 % low, spikes, worst chunk) |
| `make compare` | Same route on official build-88, Frizti v2, local build-88, local oot-5070 |
| `make record` / `make save-route NAME=x` | Record a new route with the controller (TAS) |
| `Run-OotBench.ps1 -Launch -BootOnly -Install <folder>` | Launch to gameplay and stop (for profiling) |

Build on this PC (toolchain in `D:\BuildTools`: VS 2022 Build Tools 14.44, CMake 4.1.2, Ninja
1.13.1, Qt 6.8.3 msvc2022_64, glslang 16.6.0):

```
set JOBS=10
tools\oot-bench\build-lichii.cmd <source dir> <build dir> [tag]
powershell -File tools\oot-bench\Package-LocalBuild.ps1 -BuildDir <build dir> -Dest <install folder>
```

The package copies the owner's config, saves, keys and shader cache from
`D:\ns2\lichii-build88\user`; it never writes back into it.

Profiling recipe used so far:
1. `make bench ... ENV="EDEN_NX2_GPU_PROFILE=1"`, then read the `Report: GPU thread per second`
   and `GPU back thread per second` lines in the run's `emulator.log` (zones, drains by site).
2. `Run-OotBench.ps1 -Launch -BootOnly`, then the debug server `sample` method
   (`threads=GPU,GPUBack`, `seconds=10`); the report and `.folded` stacks land in the build's
   `user\log\debug-server`.

## Experiments and results

| Change | Result on the route | Status |
| --- | --- | --- |
| Reactive flushing off | 34.9 avg vs 36.8 on | Back on (default) |
| `EDEN_NX2_READ_TRAPS=0` (no readback syncs) | 36.2 / 38.1 | Not kept (stale-data risk, small gain) |
| `EDEN_NX2_PRELOAD_ALL_PIPELINES=1` | 33.3 / 36.6 | Not kept |
| 2x resolution + SMAA | 30.9 vs 36.4 | Not kept |
| Lichii #243 + #250 + #178 | 36.4 vs ~36 | Kept (no harm, upstream candidates) |
| `EDEN_NX2_FAST_ACQUIRE=1` | 37.3 vs 36.5 (3 runs each) | Kept off by default; verified correct |
| clang-cl + PGO + ThinLTO (Touqi 2.0) | Idle: 42.6 vs 39.6 MSVC; Frizti v3 46.4 | Kept: use `build-clang-pgo.cmd` |

Ruled out because already in build-88: uniform-buffer reuse (`EDEN_NX2_UBOREUSE`), 4096 draws
per submission, Selevet build 8's ports. Pending wake (#681) would not help: the front spends
only ~2 ms/s in pending sleep.

## Most promising next steps

Measure with `make bench IDLE=1800 N=2`: the route drifts with frame rate (see WORKLOG 2026-11-07).

0. **Close the 4 FPS gap to Frizti v3:** bisect the nx2 cherry-picks on the idle benchmark, and
   record a PGO profile of Touqi 2.0 itself instead of reusing Frizti's.

1. **GPU-written command lists** (the current serial point): log which macros/addresses the
   `list writers` waits are for, which compute dispatch writes them, and whether parsing can be
   deferred (the front continues with other channels) or the producing compute submitted earlier
   so the result is ready when the front arrives.
2. **Readback without a full GPU idle:** replace `Scheduler::Finish` in
   `BufferCacheRuntime::FinishForHostRead` with a wait on the submission that wrote the range.
3. **Per-draw CPU cost on the back** (5.5 us/draw): buffer-cache translation caching and
   redundant-bind elimination (`BindHostStageBuffers`, `UpdateGraphicsBuffers`).
4. **Multi-threaded Vulkan command recording**: highest ceiling, largest refactor.

## Rules for this fork

- Do not push or open PRs on the owner's behalf; disclose AI assistance in commit messages.
- Experiment switches stay off by default; a proven fix becomes unconditional, a disproven one is
  removed. A faster run with a wrong image is a failure.
- Port existing fixes before writing new ones and keep their authors' credit (Lichii, Frizti,
  Orchid, Eglantine).
- The owner has a limited token budget: prefer `make` targets and short text reports.
