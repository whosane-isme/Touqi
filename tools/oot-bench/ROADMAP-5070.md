# Roadmap: the most complete OoT fork for an RTX 5070 PC

Target: Ryzen 5 7600X + RTX 5070, Windows 11, The Legend of Zelda: Ocarina of Time. Base: Lichii
build-88 (`55532f2`), which already carries Frizti's OoT ports, Dark's Dynamic FPS mod and Max
Resolution. Every item is measured with `tools/oot-bench` before it is kept.

## What limits us (measured 6 Nov 2026)

- Steady FPS is CPU-bound in the emulator's GPU command chain: ~36 FPS on the Kokiri route,
  GPU ~40 % busy. Faster GPU features (upscaling, resolution) do not raise it.
- Drops: pipeline builds on first sight, guest CPU reads of GPU memory (GPU sync per read),
  ASTC decode batches.
- Settings alone (reactive flushing, read traps, pipeline preload) all land at 33-38 FPS: noise.

## 1. CPU-side throughput (biggest win, in progress)

- [ ] Build build-88 from source on this PC and match the official binary's FPS.
- [ ] Port zortos293/Lichii #243, #250, #178 (reported 52 -> 58-59 FPS together on Kokiri);
      measure, check visuals, keep authors' credit.
- [ ] Profile the steady 36 FPS (`EDEN_NX2_GPU_PROFILE=1`, debug server `sample` with
      `lichii.pdb`) and attack the top zone.
- [ ] Find which guest buffers are read back (repeat addresses 0x44911000, 0x303bd000) and
      whether they can be served without a full GPU sync.

## 2. Stutter (drops)

- [ ] Keep route pipelines in the disk cache; test background preload of cached pipelines.
- [ ] Look at the 80-130 ms worker pipeline builds: which shaders, can they be prepared earlier.

## 3. Display smoothness on RTX 50 hardware

What exists in build-88:
- FSR 3 frame generation (Graphics > frame gen, type FSR3), off by default.
- LSFG frame generation: needs the owner's own Lossless Scaling DLL in `user\lossless`.
- DLSS Super Resolution through NVIDIA Streamline (`nvidia_dlss`): needs `sl.interposer.dll`
  and `nvngx_dlss.dll` in `user\streamline`. Upscaling only.

What is missing and would make this fork stand out:
- [ ] **DLSS Frame Generation (Streamline `kFeatureDLSS_G`)**, including multi frame generation
      on RTX 50 cards. Larger project: motion vectors are not available from the guest, so it
      needs the same approach as the FSR 3 path (optical flow / interpolation-only inputs);
      check what Streamline accepts before starting.
- [ ] NVIDIA Reflex (Streamline `kFeatureReflex`) to offset frame-generation latency.

Frame generation multiplies displayed frames but does not remove drops: a 500 ms hitch is still a
500 ms hitch. Fix section 1-2 first.

## Ground rules

- Owner reviews and tests every change; AI assistance is disclosed in commits.
- Experiment switches stay off by default; proven fixes become unconditional.
- Port existing fixes before writing new ones, and credit their authors.
