# Architecture notes (performance-relevant)

Touqi inherits Lichii/Eglantine's architecture. For the GPU command path, read
[NX2_GPU_THREAD_SPLIT.md](../../NX2_GPU_THREAD_SPLIT.md) and rows 98-150 of
[NX2_NOTES.md](../../NX2_NOTES.md).

What matters for Ocarina of Time:

- **Front thread** (GPU thread): parses GPFIFO entries and command lists, runs the compiled
  Turing macros (MME JIT) against register mirrors, sends method writes to the back.
- **Back thread** (GPUBack): executes method writes in order: register state, draws,
  dispatches, queries, fences, the Vulkan rasterizer and its caches.
- **Sync points** where the front waits for the back: semaphore acquires, macro DMA reads,
  command lists the GPU itself wrote (`list writers`), syncpoint waits.
- In OoT (~1,900 draws per frame) the front spends ~40 % of its time waiting for the back, the
  back ~21 % idle waiting for the front and ~8 % waiting for the GPU: the threads run largely
  in lockstep and the host GPU stays ~40 % busy. Details:
  [tools/oot-bench/HANDOFF.md](../../tools/oot-bench/HANDOFF.md).
