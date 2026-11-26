#!/bin/zsh
# Round k5: one windowed run of s34_study with the machine's state recorded beside it.
#   runtime/spikes/s34_study/tools/window_run.sh OUT_DIR TAG [s34_study --window options...]
# Run from the repository root. Stops (exit 3) when the Mac is not on AC power. Writes
# OUT_DIR/TAG.load (power, uptime, top 5 processes by CPU), OUT_DIR/TAG.log and the run's CSVs and
# summary (OUT_DIR/TAG_*.csv, TAG_summary.txt, TAG_summary.json). The window closes by itself.
out=$1; tag=$2; shift 2
mkdir -p $out
if ! pmset -g batt | head -1 | grep -q "AC Power"; then
    echo "not on AC power: stopping" | tee $out/$tag.load
    exit 3
fi
{
    date "+%F %T"
    pmset -g batt | head -2
    uptime
    ps -Ao pcpu,comm -r | head -6 | cut -c1-110
} > $out/$tag.load
tools/perf/gpu_run.sh 150 runtime/target/release/s34_study --window --out=$out --tag=$tag "$@" > $out/$tag.log 2>&1 < /dev/null
code=$?
{ echo "after:"; uptime; ps -Ao pcpu,comm -r | head -6 | cut -c1-110; } >> $out/$tag.load
exit $code
