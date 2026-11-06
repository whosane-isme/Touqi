# Ocarina of Time (Switch 2) on Ryzen 5 7600X + RTX 5070 — fork comparison notes

Private working notes, 6 November 2026. Not upstream documentation and not a benchmark claim
for other hardware.

## Test machine

| Item | Value |
| --- | --- |
| CPU | AMD Ryzen 5 7600X (6 cores / 12 threads) |
| GPU | NVIDIA GeForce RTX 5070 12 GB, driver 610.88 |
| RAM | 32 GB |
| OS | Windows 11 Pro |
| Game | `0400486024DEC000`, v131072 (display 2.0.0), NUP base game |

Common settings: Vulkan, Docked, GPU accuracy Fast, CPU accuracy Auto, async shaders and
presentation on, disk shader cache on. One emulator at a time (each holds ~14 GB).

## Key finding: the slowdown is not the graphics card

While walking outdoors in Selevet build 8, the RTX 5070 read **~35 % utilization at 62 W of a
250 W limit**, and the emulator process used ~6 CPU cores' worth of time. That build was also
running at **half internal resolution** (see the resolution note below), yet FPS stayed in the
low-to-mid 30s, the same as Frizti v2 at 1x.

So lowering resolution (2K -> 1080p, or 1x -> 0.5x) is not expected to raise FPS meaningfully on
this machine. The limit is CPU-side emulation work (guest CPU, GPU command processing, draw
setup, synchronisation). Which of those dominates is still unproven; it needs a symbolized
thread profile.

## Resolution enum differs between forks

The per-game config stores `resolution_setup=3`. In Frizti v2 / Lichii that logs as `Res1X`. In
Selevet build 8 the same value logs as `Res1_2X` (half resolution). When copying a config between
forks, check the `Renderer.resolution_setup` line in the log instead of trusting the number.

## Builds tried

FPS from the emulator's own `last 600 presents: frame N us` log lines (mean of 600 presented
frames; 1e6 / N). These are window means, not percentiles.

| Build | Source | Result here |
| --- | --- | --- |
| Eglantine `fix/oot-blackscreen` `743d5bbaed` | Djihads80/Eglantine | Kept as reference; not the selected build |
| Lichii build 83 (MSVC) | zortos293/Lichii | Video works; severe stalls (a ~22 s frame recorded) |
| Lichii build 83 (PGO) | zortos293/Lichii | AV1 video decode failed in our test |
| **Frizti v2** `765659af4c` | Frizti/Lichii | Best so far. Outdoors: ~31 FPS walking, ~38 FPS standing (scripted input test, two passes) |
| Selevet performance 8 (fix 25) | sylvieistaken/selevet-eglantine | Boots on RTX 5070, AV1 works, built-in Max Resolution + Dynamic FPS applied. Warm gameplay windows 26–32 ms -> **~31–39 FPS**, same range as Frizti v2, at half resolution. Owner rated it poor. Adds one frame of latency (`EDEN_NX2_FRAMES_AHEAD=0` disables). |
| Lichii build 88 `55532f2` (MSVC, non-PGO) | zortos293/Lichii | Boots on RTX 5070 at 1x, AV1 works, built-in Max Resolution + "Dynamic FPS by Dark" applied. Owner: **graphics better than the other builds**, FPS felt very bad. First session on a cold shader cache: 30–40 FPS windows with stalls up to ~2 s (14 frames over 100 ms in one window) during t=48–83 s, then steady 59.9 FPS windows (max frame ~18 ms) from t=93–153 s. Owner confirmed the 60 FPS windows were walking outdoors; steady 59.9 FPS continued through t=213 s. **Best build on this PC so far.** Note: this counts presented frames; whether every present is a unique game frame (Dynamic FPS mod) was not verified separately. 16 `tic_limit` texture-descriptor assertions in that log. |

## Forks reviewed but not run

- **riyadhHDA/wichforks** is a guide, not an emulator. For OoT it points to Lichii / Frizti and
  warns that 60 FPS clips are area-specific and the game is CPU-bound.
- **MythosOfs/Orchid** v0.7.5: AMD-focused; OoT FPS unmeasured. Its commit `9e3538a` (bounded
  texture-descriptor reads) matches an `index <= tic_limit` assertion seen in our Frizti logs.
  This is a stability lead, not an FPS fix.
- **Frizti/Lichii** `nx2` after the `frizti-v2` tag: only a README commit; it is 352 commits behind
  upstream Lichii. Lichii build 88 says it integrated "the reviewed Frizti performance ports".

## Practical advice for this PC

- Keep each build in its own folder with a portable `user` folder; copy saves only while all
  emulators are closed, and take the newest `nand/user/save/.../0400486024DEC000` folder.
- Don't share shader caches between forks.
- Lichii recommends CPU Clock **Normal** with the bundled Dynamic FPS mod.
- A faster single-core CPU would help more than a faster GPU for this game right now.

## Next steps

1. Use Lichii build 88 (`D:\ns2\Launch-OOT-Lichii-88.cmd`) as the main build; its stutter should drop as the shader cache fills. Recheck the same route after a restart (warm cache).
2. Take a short symbolized CPU-thread profile on the best build to find the dominant cost.
3. Investigate the texture-descriptor assertion separately (Orchid `9e3538a`).
