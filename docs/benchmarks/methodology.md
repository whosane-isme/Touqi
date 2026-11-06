# Benchmark methodology

## One run

`make bench LABEL=<name> INSTALL=<build folder> [ENV="A=1"] [SET="ini_key=value"]`:

1. Closes any running emulator, applies per-run ini values (restored after boot), starts the
   build with the local debug server (`EDEN_NX2_DEBUG_SERVER=127.0.0.1:6545`) and the frame log
   (`EDEN_NX2_FRAME_LOG=<run>/frames.csv`).
2. Presses A until the save loads (detects the loading dip and steady frames afterwards).
3. Replays the recorded route through `input_sequence` in 10-frame chunks.
4. Records per-present frame/fence/composite/pacing times (`frames.csv`), per-chunk wall time
   (`chunks.csv`), the emulator log, start/end screenshots and a `summary.json`.

## Metrics

| Metric | Source | Notes |
| --- | --- | --- |
| P50 / P95 / P99 / max frame time, frames over 33 ms | `frames.csv`, only the route's presents | Primary metric |
| Average FPS | route frames / wall time | Secondary |
| Spikes and their causes | `chunks.csv` + log events around each spike (`make drops`) | Pipeline builds, CPU reads of GPU memory, ASTC decodes |
| GPU-thread time by zone, drains by site | `EDEN_NX2_GPU_PROFILE=1`, log lines every 10 s | Where front/back threads spend time |
| Function-level CPU profile | debug server `sample` (`Run-OotBench.ps1 -BootOnly`) | Lambda names can be misattributed |

## Comparing

- Same route, same save, warm shader cache, nothing else running. One emulator at a time.
- At least 3 runs per option: the same build varies 33-39 FPS average between runs.
- Judge by P95/P99 and frames over 33 ms first, average FPS second.
- A faster run with a wrong image or changed gameplay is a failure. Check the start/end
  screenshots; experiments that change synchronization need a check mode comparing against the
  safe path, as `EDEN_NX2_FAST_ACQUIRE_CHECK=1` does.

## Known limits

- Frame generation (FSR3/LSFG) creates host frames the game never sees: not measured.
- Replays are not fully deterministic (thread timing, shader cache state); the route tolerates
  small drift, but long routes may diverge. Record build hash, settings and driver per run
  (`config.json`, `summary.json`, the emulator log header).
