# Optimization log

Short index of performance work. The detailed, chronological record is
[tools/oot-bench/WORKLOG.md](../../tools/oot-bench/WORKLOG.md) and the current summary is
[tools/oot-bench/HANDOFF.md](../../tools/oot-bench/HANDOFF.md).

| Date | Change | Result | Status |
| --- | --- | --- | --- |
| 2026-11-06 | Merge Lichii #243, #250, #178 | no gain on the Kokiri route | kept |
| 2026-11-06 | `EDEN_NX2_FAST_ACQUIRE` (`puller.cpp`) | 0 wrong of 32,768 checked; FPS within noise; waits moved to GPU-written lists | off by default |
| 2026-11-06 | `EDEN_NX2_FRAME_LOG` (`nx2_gsv.h`) | enables P50/P95/P99 per route | diagnostic |
| 2026-11-06 | Settings: reactive flushing, read traps, preload, 2x + SMAA | no gain | reverted |
| 2026-11-06 | Combined: Lichii `perf/dkb-back-record`, #264, #268, #259 (opt-in `EDEN_NX2_PREFLUSH`, off), page-mark batching / usage-mask patch | 3 runs: avg 36.5/39.5/38.5, P95 32.1-33.8 ms (was 33.3-35.3), worst frame 61-67 ms (was 71-178), 57-77 frames > 33 ms (was 68-91) | kept |

Failed or unproductive approaches are recorded on purpose, with numbers, so nobody repeats them
without a new reason.
