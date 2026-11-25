#!/bin/zsh
# Renders the owner-review set of round k2 (appear-and-settle motion) and round k1 (rounded rock
# edges): a regression check against the k1 commit's stills, the rock views, the settle
# sequences as 30 frame-a-second flipbooks and as full-size key frames, the frame costs at
# 3024x1964 in the moving-camera mode, and the edit-locality test.
#
# Run detached on the Mac, from anywhere:
#   nohup art/lookdev/20261125_settle/checks/render_settle.sh [OUT] > /tmp/render_settle.log 2>&1 &
# OUT defaults to art/lookdev/20261125_settle. A finished run leaves OUT/<name>.ok and is skipped
# next time; OUT/DONE is written at the end and OUT/FAILED lists runs that did not finish.
set -u
cd ${0:A:h}/../../../..
OUT=${1:-art/lookdev/20261125_settle}
REF=runtime/data/reference
SHOT=runtime/spikes/s34_study/tools/shot.sh
mkdir -p $OUT
rm -f $OUT/DONE $OUT/FAILED

run() {  # run NAME SECONDS ARGS...
  local name=$1 secs=$2; shift 2
  if [ -f $OUT/$name.ok ]; then echo "skip $name"; return; fi
  rm -rf $OUT/$name
  tools/perf/gpu_run.sh $secs $SHOT $OUT/$name --tag=$name --metrics=$OUT/$name/metrics.json "$@" > $OUT/$name.log 2>&1
  local rc=$?
  echo "$(date +%H:%M:%S) $name rc=$rc"
  if [ $rc -eq 0 ] && grep -q -E "^FRAME|^EDIT" $OUT/$name.log && ! grep -q "panicked" $OUT/$name.log; then touch $OUT/$name.ok; else echo $name >> $OUT/FAILED; fi
}

L7301="--layout=$REF/layout_7301_0.json --seed=7301 --body=karst"

# 1. With no edit running nothing may change: the three stills the k2 scratch rendered from the
#    k1 commit (f0a77fe), again with this build.
run regress 600 ${=L7301} --views=game,terrace_close,outer_hull
# 2. Round k1 (rounded rock edges), after: the rock views. "Before" is the k1 round's own render of
#    81d1f12, copied below when it is still on the machine.
run rocks 900 ${=L7301} --views=cliff_close,foot_front,outer_hull,terrace_close,game
if [ -d /tmp/tsw_k1/before ] && [ ! -d $OUT/rocks_before ]; then
  mkdir -p $OUT/rocks_before && cp /tmp/tsw_k1/before/study_*.png $OUT/rocks_before/
fi
# 3. The five settle sequences, 30 frames a second from the edit to 1.5 s, at half size.
run flip 1800 ${=L7301} --settle=all --size=1512x982
# 4. Key frames at full size.
run keys 1200 ${=L7301} --settle=all --settle-times=0,0.1,0.2,0.35,0.6,1.5
# 5. Frame cost at 3024x1964 in the moving-camera mode (scale 1, FXAA), twice, with the load.
for b in bench_a bench_b; do
  uptime > $OUT/$b.load
  run $b 1200 ${=L7301} --settle=all --settle-times=1.5 --scale=1 --fxaa --bench
  uptime >> $OUT/$b.load
done
# 6. Edit locality (unchanged code paths; checked again).
run edit 600 ${=L7301} --views=none --edit-test
touch $OUT/DONE
