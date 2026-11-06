# Roadmap: the CPU-side bottleneck in Ocarina of Time (oot-5070)

Goal: hold 60 FPS on the Kokiri Forest route on a Ryzen 5 7600X + RTX 5070, without drops, and
without visual regressions. Every step is measured with `make bench` (repeated runs, same route)
and recorded in `WORKLOG.md`.

## What we know

- The host GPU is not the limit (~40 % busy, 62-82 W of 250 W). Steady FPS (~36 on the route,
  ~37 at the spawn view, ~52 on lighter stretches) follows how much work the scene sends.
- Emulated GPU commands run on a split chain: the **front** thread parses command lists and
  macros, the **back** thread records Vulkan work. The game waits on syncpoints the front has not
  queued yet, so front stalls become frame time (see Eglantine #681, measured on MKW).
- OoT-specific traffic, from the Lichii PR authors: ~30k macro DMA reads/s (occlusion results,
  #243), ~88k no-op cache invalidations/s (#250), ~520k `draw.end` + ~390k same-value
  `vertex_buffer.count` writes/s (#178). Our log: ~200 guest CPU reads/s of GPU-written memory
  during drops, each a full GPU sync (`GPU::OnCPURead`).
- Settings (reactive flushing, read traps, pipeline preload) do not move the average.

## Phase 0: measure where frame time goes (done, see HANDOFF.md and WORKLOG.md)

1. `make bench ENV="EDEN_NX2_GPU_PROFILE=1"`: per-second GPU-thread time by zone (Push, Idle,
   ResumePending, PendingSleep, ...). Find how much of each frame the front spends waiting
   (drains, list waits, pending sleep) versus working.
2. Debug server `sample` on GPU/GPUBack/CPU threads with `lichii.pdb` from our own build, at the
   spawn view (steady 37 FPS). Top functions and call paths per thread.
3. Write the frame-time budget for one frame at the spawn view: front busy / front waiting /
   back busy / guest CPU. Every later step names which bucket it attacks.

## Phase 1: land the known fixes (in this branch)

- [x] Lichii #243, #250, #178 merged and built on this PC: 36.4 FPS vs ~36, no gain on this route.
- [ ] If they help: report our numbers (7600X/5070) on those PRs. That is a useful first
      contribution and helps them merge.

## Phase 2: front-thread waits

- [ ] **Pending wake** (Eglantine #681 patch, ~4 % on MKW): the GPU thread yields for 500 µs then
      sleeps 1 ms while channels wait on semaphores (`gpu_thread.cpp`, `PendingSleep` zone). A
      condition variable woken on semaphore writes, back batches and new commands removes the
      1 ms oversleep. Build-88 still has the sleep loop. Port, A/B with `EDEN_NX2_PENDING_WAKE_US=0`.
- [ ] Acquire drains and `WaitForWriters` in `DmaPusher::Step`: count per frame on OoT. #681
      found that removing one wait moves it to another, so only remove waits proven unneeded
      (log-checked like #243's `EDEN_NX2_DMA_READ_CHECK`).

## Phase 3: guest reads of GPU memory

- [ ] Identify the ~200 reads/s: the addresses repeat (0x44911000, 0x303bd000, 0x12fdfc000).
      Which buffers are they (query pool, readback buffer, CPU-visible constant data)?
- [ ] If they are report/query memory, extend #243's idea: serve reads of known report pages
      without a full GPU sync. If they are GPU-written buffers the game really reads, look at
      batching the downloads.

## Phase 4: back-thread cost per draw

- [ ] From the profile: `GraphicsPipeline::ConfigureImpl`, descriptor updates, `FlushCaching`.
      #681 saw binding as the largest single back-thread item on MKW.
- [ ] Only after Phases 0-3: the back can matter once front waits are gone.

## Phase 5: stutter

- [ ] Pipelines still built on the route despite a warm cache: check they are written to the disk
      cache and loaded on the next boot; look at the 80-130 ms worker builds.
- [ ] ASTC decode batches in drop windows: check whether they are first-sight only.

## Rules

- In-run A/B where possible (toggle at runtime, alternate), otherwise >= 3 runs each.
- A faster run with wrong images is a failure; check the route's screenshots for every change.
- Port existing fixes first and credit authors; experiment switches stay off by default.
