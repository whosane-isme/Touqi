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

## Next ideas

- If `EDEN_NX2_READ_TRAPS=0` removes the reads without glitches, find which guest buffers are
  read (addresses repeat: 0x44911000, 0x303bd000, 0x12fdfc000) and whether a narrower rule works.
- Preload all pipelines at boot; check route pipelines are in the disk cache after a run.
- Symbolized `sample` profile of the steady 37 FPS spawn view for the CPU-bound part.
