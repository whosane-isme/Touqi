# AGENTS

Read and follow the AI policy found in `docs/policies/AI.md`, and the coding policies found in `docs/policies/Coding.md`.

Do not, under any circumstances, ever submit PRs or push commits on behalf of the user.

Keep comments to a reasonable level. Do not overexplain or add/remove comments from unrelated parts of the codebase.

## Owner's setup (this fork)

- Windows 11, Ryzen 5 7600X, RTX 5070 (12 GB), 32 GB RAM. Main game: The Legend of Zelda:
  Ocarina of Time, program id `0400486024DEC000`. Disks are nearly full: budget space before
  installing toolchains or keeping build directories.
- The owner plays Lichii build-88 (`D:\ns2\lichii-build88`, ships `lichii.pdb`). Logs:
  `user\log\eden_log.txt`; each `Booting game:` line starts a session.
- Run one emulator at a time (~14 GB each). Never restore an old `user` folder over newer saves.
- The owner is new to emulator development and has a limited token budget: prefer `make`
  targets and short text reports over screenshots and long back-and-forth.

## Before writing a fix

Do not guess, and do not rewrite a fix that already exists (adapted from zortos293/Lichii's AGENTS).

1. Check `Djihads80/Eglantine` and `zortos293/Lichii` branches, open and closed PRs and issues for
   the game and symptom; read the diffs, not only the titles.
2. Port an existing fix before writing a new one, cite its PR or commit, and keep its authors' credit.
3. Write a new fix only when nothing addresses the root cause the log or a profile shows.

Known open OoT performance PRs in zortos293/Lichii (Kokiri Forest, about 52 -> 58 FPS together on a
4090/13900K): #243 (macro DMA reads without draining the split back), #250 (skip cache
invalidations on pages with nothing cached), #178 (skip instance-loop writes the back ignores).

## Measuring performance

Use the benchmark in `tools/oot-bench` (see its README and `WORKLOG.md`): `make bench`,
`make drops`, `make report`. Compare options only with repeated runs of the same route; one run
is noise. Record every experiment in `WORKLOG.md`.

Diagnostic switches present in build-88 (off unless set; pass with `make bench ENV="..."`):

| Question | Switch |
| --- | --- |
| Where GPU-thread time goes, per second by zone | `EDEN_NX2_GPU_PROFILE=1` |
| Live state, input, screenshots, log tail, thread `sample` | `EDEN_NX2_DEBUG_SERVER=127.0.0.1:6545` |
| Wrong image: dump one frame's passes | `EDEN_NX2_FRAME_DUMP=<dir>` |
| Shader A/B (reject a program as unsupported) | `EDEN_NX2_REJECT_HASH=<16-hex>,...` (restore afterwards) |
| Per-draw render state | `EDEN_NX2_RENDER_TRACE=1` |
| CPU reads of GPU memory without sync (may show stale data) | `EDEN_NX2_READ_TRAPS=0` (reactive flushing off) or `EDEN_NX2_NO_REACTIVE=1` (on) |

Experiment switches are for A/B tests only; a proven fix becomes unconditional behaviour and a
disproven one is dropped. A change that raises FPS but breaks the image is not a fix.
