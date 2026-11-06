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
