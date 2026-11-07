# OoT frame-drop work log (agent working notes)

Machine: Ryzen 5 7600X, RTX 5070 (driver 610.88), 32 GB. Build: Lichii build-88 `55532f2`
(`D:\ns2\lichii-build88`). Game ini: `user\config\custom\0400486024DEC000.ini`.
Runs: `D:\ns2\oot-lab\bench\runs` (outside the repo). Route: `routes\kokiri-walk-raw.txt`,
replayed from frame 1000 (owner's walk is frames 1058-1984).

## How to resume

- `make report` lists every run; `make drops` explains the latest; `make suite` re-runs the
  option comparison. Only one emulator at a time (~14 GB each).
- The owner's own ini has `use_reactive_flushing=false`. `-Set` changes the ini for one run and
  restores it after boot.
- The owner pushes (`make push`); the repo's AGENTS.md forbids agents from pushing.

## What is known

- Steady FPS is CPU-bound and depends on the view: ~37 at the spawn, ~52 on other stretches,
  GPU ~40 %.
- Spike causes from the log (`Analyze-OotDrops.ps1`):
  - **pipeline-build**: graphics/compute pipelines built on the GPU thread (3-40 ms each) plus
    worker builds of 80-130 ms that hold draws. A warm disk cache (1100 pipelines) still leaves
    new ones on this route.
  - **cpu-reads-gpu-memory**: `GPU::OnCPURead` waits on a GPU sync per read, ~200 reads/s in
    drop windows. With `use_reactive_flushing=false` this fork uses read traps instead
    (`core/memory.cpp` `ReadTrapsEnabled`), which still call `OnCPURead`. Turning off both:
    `EDEN_NX2_READ_TRAPS=0` (risk: stale data -> visual glitches).
  - **astc-decode**: GPU ASTC decode batches appear in some windows.
- Baseline (reactive off, read traps on): 36.2 / 35.2 FPS avg, 1-2 spikes of 500-600 ms.

## Experiments

| Label | Options | Result |
| --- | --- | --- |
| base | reactive off (owner ini) | 36.2, 35.2 FPS; spikes 2, 1 |
| suite-1 | see `make report` | running |

## Code fixes found upstream (not in build-88, need a source build)

zortos293/Lichii open PRs, all measured on OoT Kokiri village (4090/13900K, GPU accuracy Low):
#243 macro DMA reads of report memory without draining the split back (+8.5 %, OoT makes ~30k/s),
#250 page filter skips no-op cache invalidations (+3.4 %, ~88k/s), #178 skip instance-loop writes
the back ignores (~520k draw.end/s). Together ~52 -> 58-59 FPS. Their CI did not run (no
artifacts). Building needs VS Build Tools + Qt + CMake/Ninja (none installed; C: 20 GB, D: 24 GB free).

## Next ideas

- If `EDEN_NX2_READ_TRAPS=0` removes the reads without glitches, find which guest buffers are
  read (addresses repeat: 0x44911000, 0x303bd000, 0x12fdfc000) and whether a narrower rule works.
- Preload all pipelines at boot; check route pipelines are in the disk cache after a run.
- Symbolized `sample` profile of the steady 37 FPS spawn view for the CPU-bound part.

## 2026-11-06 afternoon: profile of oot-5070 (build-88 + #243 #250 #178)

Route: 36.4 FPS (same as official build-88, ~36), so the three PRs do not help on this PC/route.
Built on this PC: `D:\ns2\lichii-out\b88-prs` (profiling relink with `/OPT:REF,NOICF` via a
temporary edit of `src/CMakeLists.txt:150`; not committed).

`EDEN_NX2_GPU_PROFILE=1`, per second while walking:
- Front (GPU thread): split drain 406 ms, acquire waits 315 ms, list writers 271 ms, macro DMA
  reads 87 ms; real work (macro, push) ~190 ms. The front mostly waits for the back.
- Back (GPUBack): ~890 ms busy, 107 ms idle. 70k draws/s (~1,900 per frame), 4.2M methods/s
  (1.1M same value). Per draw ~5.5 us across bind stage buffers 80 ms, update buffers 63,
  draw 73, fill image views 36, read handles 31, dynamic state 20, pipeline lookup 17.
  Methods 191 ms, compute 57, texture upload 50, clear 38.
=> The back thread is saturated. Reaching 60 FPS needs roughly 40 % less back-thread work.

`sample` on GPUBack (10 s, spawn view; lambda names are still misattributed even with NOICF):
- RasterizerVulkan::Draw 45 %: buffer cache ~19 % (BindHostStageBuffers ~10 %, of which uniform
  uploads ~8 %: ReadBlockUnsafe copies, MappedUploadMemory, SynchronizeBuffer, TouchBuffer;
  UpdateGraphicsBuffers ~5 %; BindHostGeometryBuffers ~3 %), image descriptors/views ~4 %.
- TickWork -> FlushRegion -> DownloadMemory -> FinishForHostRead -> Scheduler::Finish: ~9 %,
  a full GPU idle wait per guest CPU read of GPU-written memory (the OnCPURead sync requests).
  Removing the reads entirely (READ_TRAPS=0) gave only ~+1-2 FPS earlier: the wait moves.
- KeplerCompute ~9 %, query CounterReport ~5 %. Non-draw method handling ~3.5 % (cb_data
  coalescing would not pay).
- Debug logs ("Native QMD control", ~1,500/s) are filtered before formatting: not a cost.

Next candidates (each needs an A/B on the route):
1. Uniform upload: skip the copy when the guest range is unchanged since the last bind.
2. Selevet-8 ports not in build-88: send queued work before fence waits, 4096-draw submits,
   uniform uploads without page-protection churn (check which are already in 88).
3. Eglantine #681 pending wake (front oversleeps 1 ms in PendingSleep).
4. Download path: wait for the specific write's fence instead of Scheduler::Finish.

## 2026-11-06: corrected diagnosis (NOICF sample, self time on GPUBack)

- Back thread: ~71 % real work, ~21 % idle waiting for the front (`BackLoop` spin 13.5 % +
  sleep 7.4 %), ~8 % waiting for the GPU (`Scheduler::Finish` from guest readbacks).
- Front: ~40 % draining (waiting for the back), plus list-writer and acquire waits.
- => Front and back run largely in lockstep. The limit is the serial chain front -> back ->
  GPU -> front, not raw back throughput. Cause: OoT generates command lists and draw parameters
  on the GPU (compute writes lists; `list writers` 7,058 waits/s, `acquire` 3,732 drains/s with
  only 304 real waits, `macro dma read` 255/s). Each forces the front to wait until the back
  and the GPU have produced the words.
- Same structure as Eglantine #681 (MKW): removing one wait moved the time to another.

Ruled out: 2x resolution + SMAA costs FPS (36.4 -> 30.9 on the route), UBO reuse already in
build-88, 4096-draw submits already in build-88, pending wake (front pending sleep 2 ms/s).

Next experiments:
1. Acquire drains: 3,732/s but only 304 waited. Check guest memory first and drain only when
   the semaphore is not yet satisfied (verify with a check mode like EDEN_NX2_DMA_READ_CHECK).
2. List-writer waits: classify which GPU-written lists OoT uses (compute culling output?) and
   whether the front can parse them later (deferred) instead of waiting.
3. Replace `Scheduler::Finish` in readbacks with a wait on the writing submission's tick.

## 2026-11-06: experiment EDEN_NX2_FAST_ACQUIRE (puller.cpp, off by default)

Idea: answer semaphore acquires on report memory from guest memory plus the queued releases
whose payload the front knows (`GpuSplit::OverlayQueuedWrites`, from #243), instead of draining
the back; also stay suspended without a drain when every queued write is known and none meets
the value. `EDEN_NX2_FAST_ACQUIRE_CHECK=1` drains anyway and compares.

- Check runs: 32,768 acquires checked, 0 let through wrongly, 0 kept waiting wrongly.
- Route, 3 runs each, profiler on: off 38.5 / 33.4 / 37.6 (avg 36.5, 10 spikes);
  on 38.1 / 38.9 / 34.9 (avg 37.3, 6 spikes). Within noise.
- Acquire drains stay ~3,000/s (most acquires are not on known report memory), and list-writer
  waits rose ~6,500 -> ~9,000/s: the front reaches the next GPU-written list sooner and waits
  there instead. Same pattern as Eglantine #681.

Conclusion: the serial point is the GPU-written command lists (compute writes lists the front
must parse). Next: find which lists/macros write them and whether their parsing can be
deferred, or the producing compute run earlier (the GPU idles ~60 %).

## 2026-11-07: clang PGO build and the idle benchmark

Touqi 2.0 built with `build-clang-pgo.cmd` (clang-cl 23, Frizti's `eglantine.profdata`, ThinLTO).
The route drifted with frame rate (Link reaches the water on slow builds, a wall on fast ones),
so `Run-OotBench.ps1 -IdleFrames` / `make bench IDLE=1800` now stands still at the spawn.

Idle, 2 runs each: Frizti v3 46.9 / 45.8; Touqi 2.0 PGO 42.3 / 42.8; Touqi 2.0 MSVC 39.6 / 39.5.
PGO + ThinLTO gives +3 FPS; Frizti v3 still leads by ~4. Details:
`docs/benchmarks/results/2026-11-07-oot-idle.md`.

Builds now call themselves "Touqi <version>" (`dist/touqi_version.txt`) in the title bar.
