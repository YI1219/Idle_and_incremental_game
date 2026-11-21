#!/bin/zsh
# plan_all.sh OUT_DIR LABEL : headless plan dump + metric for the four review layouts.
cd /Users/yi/Projects/games/the-scroll-within
L=art/lookdev/20261121_reverse_stagger
OUT=$1; LABEL=$2
mkdir -p $OUT
for pair in 7301:0 2104:0 4242:1 913:2; do
  seed=${pair%%:*}; preset=${pair##*:}
  /opt/homebrew/bin/godot --headless --path . --script res://$L/checks/plan_dump.gd -- --out=$PWD/$OUT/plan_$seed.json --seed=$seed --preset=$preset > $OUT/plan_$seed.log 2>&1 < /dev/null
  grep -E "SCRIPT ERROR|^ERROR" $OUT/plan_$seed.log | head -5
  python3 $L/checks/plan_metric.py $OUT/plan_$seed.json $OUT/plan_$seed.png --label $LABEL --json $OUT/metric_$seed.json
done
