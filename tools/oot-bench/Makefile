# OoT benchmark shortcuts (Windows, GNU make). Run from this folder: make <target>
#
#   make play                         start the game normally
#   make debug                        start the game with the debug server (for record/bench)
#   make record                       start recording input; run again to stop and save
#   make save-route NAME=my-walk      copy the last recording into routes/my-walk.txt
#   make bench LABEL=x [N=3] [ENV="A=1;B=0"] [SET="key=value"]
#                                     fresh launch + replay, N times, with a drop report each
#   make drops [RUN=<run dir>]        explain each spike of a run (default: latest)
#   make report                       one line per run, to compare options
#   make suite                        the standard option comparison (several runs)
#   make compare                      the same route on each build (official, Frizti v2, local)
#   make bench ... INSTALL=<folder>   benchmark another build folder
#   make push                         push oot-5070 and the notes branch to your fork (you run it)

PS     = powershell -NoProfile -ExecutionPolicy Bypass -File
LABEL ?= bench
N     ?= 1
ENV   ?=
SET   ?=
RUN   ?=
NAME  ?= route
INSTALL ?=
IDLE  ?= 0
TASDIR ?= D:/ns2/frizti-v2/Lichii-Frizti-v2/user/tas

.PHONY: play debug record save-route bench compare drops report suite push push-current

play:
	cmd /c start "" /D "D:\ns2\lichii-build88" "D:\ns2\lichii-build88\lichii.exe" "D:\ns2\game\The Legend of Zelda Ocarina of Time Switch 2 NUP Base Game\The Legend of Zelda Ocarina of Time [0400486024DEC000][v131072].nup"

debug:
	cmd /c Launch-Lichii88-Debug.cmd

record:
	$(PS) Toggle-OotTas.ps1 -Item Record

save-route:
	cmd /c copy /Y "$(subst /,\,$(TASDIR))\record.txt" "routes\$(NAME).txt"

bench:
	$(PS) Invoke-OotBenchSet.ps1 -Label "$(LABEL)" -Count $(N) -Env "$(ENV)" -Set "$(SET)" -Install "$(INSTALL)" -IdleFrames $(IDLE)

# The same route on each build, 2 runs each. Builds need the debug server and a portable user folder.
compare:
	$(MAKE) bench LABEL=b88-official N=2 INSTALL="D:\ns2\lichii-build88"
	$(MAKE) bench LABEL=frizti-v2 N=2 INSTALL="D:\ns2\frizti-v2\Lichii-Frizti-v2"
	$(MAKE) bench LABEL=b88-local N=2 INSTALL="D:\ns2\lichii-local\base"
	$(MAKE) bench LABEL=b88-3prs N=2 INSTALL="D:\ns2\lichii-local\prs"
	$(MAKE) report

drops:
	$(PS) Analyze-OotDrops.ps1 -Run "$(RUN)"

report:
	$(PS) Report-OotRuns.ps1

# Each option alone against the baseline, 2 runs each.
suite:
	$(MAKE) bench LABEL=base N=2
	$(MAKE) bench LABEL=reactive-on N=2 SET="use_reactive_flushing=true"
	$(MAKE) bench LABEL=no-read-traps N=2 ENV="EDEN_NX2_READ_TRAPS=0"
	$(MAKE) bench LABEL=preload N=2 ENV="EDEN_NX2_PRELOAD_ALL_PIPELINES=1"
	$(MAKE) report

push:
	git -C "$(CURDIR)" push -u origin oot-5070 notes/oot-rtx5070-findings

push-current:
	git push -u origin HEAD
