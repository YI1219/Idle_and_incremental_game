#!/bin/zsh
# Spike S1 test. Hangs the wallpaper window, records where it sits in the window
# order, covers it with an opaque window for a while, and leaves a per-second
# log of frames, simulation ticks, occlusion and processor time.
#   run_test.sh OUT_DIR [stop|draw]
# Run it through tools/perf/gpu_run.sh from the repository root.
set -u
OUT=${1:-/tmp/tsw_s1}
POLICY=${2:-stop}
HERE=${0:A:h}
BIN=$HERE/../../../target/release
mkdir -p $OUT
$BIN/s1_wallpaper --mode=wallpaper --fps=30 --seconds=46 --when-covered=$POLICY --out=$OUT/wallpaper_$POLICY.json > $OUT/wallpaper_$POLICY.log 2>&1 &
WALL=$!
sleep 6
$BIN/winlist $WALL > $OUT/winlist_$POLICY.txt 2>&1
sleep 8
$BIN/s1_wallpaper --mode=cover --fps=10 --seconds=12 > $OUT/cover_$POLICY.log 2>&1 &
COVER=$!
sleep 6
$BIN/winlist $WALL > $OUT/winlist_covered_$POLICY.txt 2>&1
wait $COVER
wait $WALL
echo "done wall_rc=$?"
