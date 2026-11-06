# Recording and replaying a route (TAS)

1. `make debug` (or let `make bench` launch) and load the save until Link is in gameplay.
2. `make record` starts input recording through the emulator's Tools > TAS > Record menu (UI
   Automation; works without keyboard focus). Play the route with the controller.
3. `make record` again stops and saves `record.txt` in the emulator's TAS folder.
4. `make save-route NAME=<name>` copies it to `tools/oot-bench/routes/<name>.txt`.

The file has one line per presented frame (`frame buttons lx;ly rx;ry`, sticks in
-32767..32767), the same unit the debug server's `input_sequence` replays in. The benchmark
replays from `-FromFrame` (default 1000, after the boot presses in the recording) and boots to
gameplay by itself, so menu timing differences do not matter.

Current route: `routes/kokiri-walk-raw.txt`, a ~15 s walk around Kokiri Forest with camera turns
and an area change, recorded by the owner on 6 Nov 2026.
