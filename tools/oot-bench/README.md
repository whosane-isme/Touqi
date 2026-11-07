# OoT walk benchmark (Windows, Lichii build 88)

**Start with [HANDOFF.md](HANDOFF.md)**: current status, measured results, what is hard, next steps.

Replays a recorded controller walk through Kokiri Forest via the emulator's local debug server,
reports FPS and frame-time spikes, and explains each spike from the emulator log.
Everything runs through `make` in this folder (GNU make + Windows PowerShell).

| Command | What it does |
| --- | --- |
| `make play` | start the game normally |
| `make debug` | start the game with the debug server |
| `make record` | start recording your input; run again to stop (saved as `record.txt`) |
| `make save-route NAME=x` | copy the recording to `routes/x.txt` |
| `make bench LABEL=x N=3 ENV="A=1" SET="key=value"` | fresh launch + replay N times, with drop causes |
| `make drops` | explain each spike of the latest run (`RUN=<dir>` for another) |
| `make report` | one line per run: label, options, avg FPS, ~1% low, spikes, worst |
| `make suite` | standard option comparison |
| `make push` | push this branch to your fork |

Results go to `D:\ns2\oot-lab\bench\runs\<time>-<label>\` (`summary.json`, `chunks.csv`,
`drops.txt`, `emulator.log`). Timing: 10-frame chunks via `input_sequence`; a spike is a chunk
50 ms+ and 1.6x slower than the run's median. Paths point at `D:\ns2`; adjust for another PC.
Notes and experiment history: `WORKLOG.md`.
