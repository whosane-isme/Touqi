# OoT walk benchmark (Windows, Lichii build 88)

Replays a recorded controller walk through Kokiri Forest via the emulator's local debug server
and reports FPS and frame-time spikes. No screenshots or external tools needed.

1. Record a route once: start the game with `Launch-Lichii88-Debug.cmd`, load the save,
   run `Toggle-OotTas.ps1 -Item Record`, play, run it again to stop. The emulator writes
   `record.txt` in its TAS folder; copy it to `routes/`.
2. Benchmark: `.\Run-OotBench.ps1 -Launch -Label my-change`
   (`-Launch` closes any emulator, boots, presses A until the save loads, then replays.)
   Without `-Launch` it replays from wherever Link stands.
3. Results land in `runs/<time>-<label>/`: `summary.json` (avg FPS, approximate 1% low,
   spikes with emulator uptime to match against `emulator.log`), `chunks.csv`, the log.

Timing: the route is sent in 10-frame chunks with `input_sequence`; each chunk's wall time is the
frame time at ~0.17 s resolution. A spike is a chunk 50 ms+ and 1.6x slower than the median.
Paths in the scripts point at `D:\ns2`; adjust for another machine.
