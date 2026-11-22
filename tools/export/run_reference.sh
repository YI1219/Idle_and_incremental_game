#!/bin/zsh
# Captures the frozen Godot project's reference frames at 3024x1964, twelve
# cameras per set. Run from the repository root; each set goes through
# tools/perf/gpu_run.sh (mains power check, one GPU job at a time).
#   tools/export/run_reference.sh art/lookdev/20261122_g1/godot_baseline
set -u
OUT=${1:?output folder inside the repository}
GODOT=/opt/homebrew/bin/godot
mkdir -p $OUT
sets=(
  "day:--suite=quick"
  "dusk:--suite=quick --progress=0.83"
  "night:--suite=night"
  "held2104:--suite=quick --seed=2104 --preset=0"
  "held4242:--suite=quick --seed=4242 --preset=1"
  "held913:--suite=quick --seed=913 --preset=2"
)
for entry in $sets; do
  name=${entry%%:*}
  opts=${entry#*:}
  if [ -f $OUT/$name/captures.json ]; then
    echo "skip $name (already captured)"
    continue
  fi
  tools/perf/gpu_run.sh 900 $GODOT --path . --script res://tools/export/capture_reference.gd -- --out=$OUT/$name ${=opts} > $OUT/$name.log 2>&1
  echo "$name rc=$? $(grep -c 'LOOKDEV saved' $OUT/$name.log) frames; $(grep '^LOOKDEV:' $OUT/$name.log | cut -c1-120)"
done
