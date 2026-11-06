# Using more of the GPU: notes for the oot-5070 work

Agent reference, written 6 Nov 2026 from general Vulkan/C++ performance practice (Vulkan spec and
guide, NVIDIA "Vulkan dos and don'ts", GPU-driven rendering talks, Agner Fog's C++ optimization
manual) and from this repo's measurements. Each idea says what it would cost and whether it fits
an emulator. Measured facts are in `WORKLOG.md`.

## The situation in one paragraph

The guest (OoT) issues ~1,900 draws per frame. The emulator's back thread translates each draw into
Vulkan state + `vkCmdDraw*` on one CPU thread at ~5.5 us per draw, and is ~90 % busy. The RTX 5070
is ~40 % busy. So the frame rate is the back thread's throughput. "Using more GPU" helps in two
different ways that must not be confused:

1. **Spend the idle GPU on image quality and smoothness** (free, available now).
2. **Move CPU work onto the GPU** so the back thread does less per draw (real engineering).

## 1. Free GPU work (no FPS cost while CPU-bound)

| Setting | What it does | Notes |
| --- | --- | --- |
| Internal resolution 1.5x/2x (`resolution_setup` 5/6) | Sharper image | GPU-bound only if it exceeds ~100 % GPU; check at 2x |
| SMAA (`anti_aliasing=2`) | Edge anti-aliasing | Cheap post pass |
| FSR3 frame generation (`frame_gen=true`, `frame_gen_type=1`) | Interpolates frames on the GPU: ~36 -> ~72 displayed | Adds ~1 frame latency; does not remove hitches; UI/fog artifacts possible |
| DLSS (`nvidia_dlss`, needs Streamline DLLs in `user\streamline`) | Upscaling | Pointless for FPS here (not GPU-bound); useful only as AA |

Rule: verify with the route that the average FPS does not drop (it should not while GPU < 100 %).

## 2. Moving CPU work to the GPU (and making each draw cheaper)

Ordered by expected value for this emulator.

### 2.1 Fewer Vulkan calls per draw (CPU)
- **Dynamic state everywhere** (EDS1/2/3, `VK_EXT_vertex_input_dynamic_state`): fewer pipeline
  variants and lookups. Build-88 already uses EDS2 (`dyna_state`). Check EDS3 coverage on NVIDIA
  (blend/color-write masks) to cut `pipeline lookup` + `FixedPipelineState::Refresh`.
- **Push descriptors / descriptor buffers** (`VK_KHR_push_descriptor`, `VK_EXT_descriptor_buffer`):
  writing descriptors straight into memory instead of building `VkWriteDescriptorSet`s. Build-88
  pushes descriptors (`push descriptors` zone 12 ms/s); the larger cost is *finding* the views
  (`fill image views` 36, `read handles` 31 ms/s), i.e. guest-to-host lookups, not Vulkan.
- **Redundant-state elimination**: compare against the last bound state per draw (pipeline,
  vertex/index buffers, descriptor sets) and skip identical binds. Cheap and safe; must be
  measured, NVIDIA drivers already filter some.

### 2.2 Less CPU memory traffic per draw
- **Uniform data**: ~8 % of the back thread copies guest constant-buffer bytes into a stream
  buffer per draw. Build-88 already reuses identical binds within a command buffer
  (`EDEN_NX2_UBOREUSE`). Next step would be **binding guest memory directly**: keep a persistent
  host-visible, device-local mirror (ReBAR, `DEVICE_LOCAL | HOST_VISIBLE`, 12 GB on the 5070) of the
  constant-buffer pages and bind offsets into it, so the per-draw copy disappears. Writes from
  `cb_data` methods then go straight into the mirror. Correctness risk: the GPU must not read a
  range the CPU rewrites before the draw that used the old contents executes -> needs per-range
  versioning (copy-on-write ring), which is what the stream copy currently gives for free.
- **Buffer cache lookups** (`UpdateGraphicsBuffers`, `BindHostGeometryBuffers`, `GpuToCpuAddress`,
  `GetSubmappedRange`): cache the last translation per binding slot; most draws reuse the same
  vertex/index buffers. Plain C++ (memoization, fewer hash lookups, avoid `std::function`).

### 2.3 GPU-driven work (bigger projects)
- **Multi-draw indirect** (`vkCmdDrawIndexedIndirectCount`): batch many guest draws that share a
  pipeline into one host call. Hard for an emulator: per-draw state changes between guest draws.
- **Device-generated commands** (`VK_EXT_device_generated_commands`, supported on RTX 50): the GPU
  writes its own draw/bind commands. Would only pay if the guest's per-draw state could be
  expressed as GPU-readable tokens; research-level.
- **Readback without full idle**: the back currently calls `Scheduler::Finish` for each guest read
  of GPU-written memory (~9 % of the back thread). Timeline semaphores let the CPU wait for the
  *specific* submission that wrote the data; with host-visible device memory the copy itself can be
  skipped. Earlier test: removing the reads entirely only gave +1-2 FPS, so this is a hitch fix more
  than a throughput fix.

### 2.4 Parallelism (CPU, but uses idle cores)
- The 7600X has 6 cores / 12 threads; the GPU-front and back threads plus guest CPU threads use
  ~5. **Recording Vulkan command buffers on several threads** (secondary command buffers, one per
  render pass chunk) is the standard way to scale draw submission; it requires the back's state
  tracking to be split per recorder. Large refactor, highest ceiling.
- Cheaper: move work that does not need ordering off the back thread (texture uploads/decodes
  50 ms/s, pipeline builds already on workers, fence/signal bookkeeping).

## 3. C++ habits that matter on the hot path (~70k draws, ~4M methods per second)

- No allocation per draw (`operator new` and `RtlAllocateHeap` show up in the profile): reuse
  scratch vectors, small fixed arrays.
- No locks per draw if the data is single-thread owned (`SpinRecursiveMutex`, `SRWLock` show up).
- Branch on the common case first; mark rare paths `[[unlikely]]`.
- Keep hot per-draw state in contiguous arrays (cache lines), avoid pointer chasing through maps.
- Measure with the zone profiler (`EDEN_NX2_GPU_PROFILE=1`) and the `sample` method; always
  confirm with the route benchmark (3 runs) before keeping a change.

## 4. Order of work

1. Free GPU usage: 2x resolution + SMAA + FSR3 frame gen test on the route (no code).
2. Redundant-bind elimination and per-slot translation caches in the buffer/texture cache.
3. Readback via specific fences instead of `Scheduler::Finish` (hitches).
4. Persistent ReBAR mirror for constant buffers (largest single CPU item, needs care).
5. Multi-threaded command recording (largest ceiling, largest effort).
