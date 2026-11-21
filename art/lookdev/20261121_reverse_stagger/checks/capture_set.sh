#!/bin/zsh
# capture_set.sh [SUBDIR_PREFIX]
# The review set of the earlier cliff packages, unchanged: same capture script,
# cameras, layouts and light (default, seeds 2104 / 4242 / 913, dusk 0.83).
# Each run goes through tools/perf/gpu_run.sh (AC power check, one GPU job at a time).
cd /Users/yi/Projects/games/the-scroll-within
L=art/lookdev/20261121_reverse_stagger
CAP=res://art/lookdev/20261114_cliff_optimization/checks/capture.gd
P=${1:-final}
run() {
  name=$1; shift
  tools/perf/gpu_run.sh 900 /opt/homebrew/bin/godot --path . --script $CAP -- --suite=full --out=res://$L/$name "$@" > $L/checks/capture_$name.log 2>&1 < /dev/null
  echo "$name rc=$? files=$(ls $L/$name 2>/dev/null | grep -c png) errors=$(grep -cE 'SCRIPT ERROR|^ERROR' $L/checks/capture_$name.log)"
}
run $P
run ${P}_held2104 --seed=2104 --preset=0
run ${P}_held4242 --seed=4242 --preset=1
run ${P}_held913 --seed=913 --preset=2
run ${P}_night --progress=0.83
