# 2026-11-06: Ocarina of Time, Kokiri Forest route

Hardware: [owner-7600x-5070](../hardware-profiles.md). Route: `kokiri-walk-raw`.

## Builds compared (average FPS, multiple runs)

| Build | Avg FPS | Notes |
| --- | --- | --- |
| Frizti v2 (earlier scripted test, different route) | ~31 walking, ~38 standing | |
| Selevet performance build 8 | ~31-39 | ran at half resolution |
| Lichii build-88 official | 33-38 | best image of the forks tried |
| Touqi (build-88 + Lichii #243/#250/#178), local MSVC build | 35.4-38.2 | no gain over build-88 |
| Touqi + `EDEN_NX2_FAST_ACQUIRE=1` | 34.9-38.9 | within noise |

## Frame-time percentiles (Touqi baseline, 3 runs)

| Run | P50 | P95 | P99 | Max | Frames > 33 ms |
| --- | --- | --- | --- | --- | --- |
| 1 | 24.69 ms | 35.32 ms | 48.07 ms | 177.78 ms | 91 |
| 2 | 23.47 ms | 33.34 ms | 43.95 ms | 71.39 ms | 68 |
| 3 | 24.67 ms | 34.68 ms | 41.44 ms | 82.32 ms | 91 |

## Option tests (average FPS)

Reactive flushing off 34.9 vs on 36.8; read traps off 36.2 / 38.1; pipeline preload
33.3 / 36.6; 2x resolution + SMAA 30.9 (vs 36.4). None kept.

Full log: [tools/oot-bench/WORKLOG.md](../../../tools/oot-bench/WORKLOG.md).

## Combined change (Lichii perf/dkb-back-record + #264 + #268 + #259 opt-in + tracking patch)

| Run | Avg FPS | P50 | P95 | P99 | Max | Frames > 33 ms |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 36.5 | 24.27 ms | 33.10 ms | 47.37 ms | 67.05 ms | 63 |
| 2 | 39.5 | 22.48 ms | 32.12 ms | 43.68 ms | 62.98 ms | 57 |
| 3 | 38.5 | 22.84 ms | 33.79 ms | 41.38 ms | 60.77 ms | 77 |

Not merged: Lichii #192 (conflict in `vk_pipeline_cache.cpp`), `perf/gpu-parallel-record`,
`perf/dkb-front-waits`, `fix/readback-fence-v2` (conflicts). `EDEN_NX2_PREFLUSH=1` is untested
here (its author reports Kokiri ~26 -> ~40 FPS on a 9600X/5060 with some flicker).
