#!/bin/zsh
# Renders and measures the owner-review set of round k5 (rock massing and repairs, settle motion
# for construct and removal, the construction demonstration from one mound, real-time window).
#
# Run detached on the Mac:
#   nohup art/lookdev/20261126_k5/checks/render_k5.sh [OUT] > /tmp/render_k5.log 2>&1 &
# OUT defaults to art/lookdev/20261126_k5. A finished step leaves OUT/<name>.ok and is skipped next
# time; OUT/DONE is written at the end, OUT/FAILED lists steps that did not finish. Steps run one
# after another, so no two of them share the GPU.
set -u
cd ${0:A:h}/../../../..
OUT=${1:-art/lookdev/20261126_k5}
REF=runtime/data/reference
SHOT=runtime/spikes/s34_study/tools/shot.sh
BIN=runtime/target/release/s34_study
# The build of 3bc9d74 (the k2 package), kept for the "before" rock frames.
BEFORE_BIN=${BEFORE_BIN:-/tmp/tsw_k5/s34_k4}
mkdir -p $OUT
rm -f $OUT/DONE $OUT/FAILED
L7301="--layout=$REF/layout_7301_0.json --seed=7301 --body=karst"
ROCKVIEWS=whole,side_106,side_286,reverse,foot_reverse,outer_hull,cliff_close,game,close,terrace_close

ac() { pmset -g batt | head -1 | grep -q "AC Power" || { echo "not on AC power" >> $OUT/FAILED; exit 3; } }

run() {  # run NAME SECONDS ARGS...  (through shot.sh: frames plus 1300 px copies)
  local name=$1 secs=$2; shift 2
  if [ -f $OUT/$name.ok ]; then echo "skip $name"; return; fi
  ac
  rm -rf $OUT/$name
  tools/perf/gpu_run.sh $secs $SHOT $OUT/$name --tag=$name --metrics=$OUT/$name/metrics.json "$@" > $OUT/$name.log 2>&1
  local rc=$?
  echo "$(date +%H:%M:%S) $name rc=$rc"
  if [ $rc -eq 0 ] && grep -q -E "^FRAME|^EDIT" $OUT/$name.log && ! grep -q "panicked" $OUT/$name.log; then touch $OUT/$name.ok; else echo $name >> $OUT/FAILED; fi
}

# 1. Rock massing: after (this build) and before (3bc9d74), the same ten views, full size.
run rocks 1200 ${=L7301} --views=$ROCKVIEWS
if [ ! -f $OUT/rocks_before.ok ] && [ -x $BEFORE_BIN ]; then
  ac
  rm -rf $OUT/rocks_before; mkdir -p $OUT/rocks_before
  tools/perf/gpu_run.sh 1200 $BEFORE_BIN --out=$OUT/rocks_before --tag=rocks_before ${=L7301} --views=$ROCKVIEWS > $OUT/rocks_before.log 2>&1 < /dev/null
  grep -q "^FRAME" $OUT/rocks_before.log && touch $OUT/rocks_before.ok || echo rocks_before >> $OUT/FAILED
fi
# 2. Hole check over the twelve review views and the edit-locality test.
run parts 1200 ${=L7301} --views=all --debug=parts --grass=off --size=1512x982
run edit 600 ${=L7301} --views=none --edit-test
# 3. Settle motion, every sequence (construct and remove): 30 frames a second at half size, and
#    full-size key frames.
run flip 2400 ${=L7301} --settle=all --size=1512x982
run keys 2400 ${=L7301} --settle=all --settle-times=0,0.1,0.2,0.35,0.6,1.5
# 4. The construction demonstration: recorded (encoded while it renders) and its stills.
if [ ! -f $OUT/construction.ok ]; then
  ac
  rm -rf $OUT/construction; mkdir -p $OUT/construction
  python3 -u ${0:A:h}/encode.py $OUT/construction rec $OUT/construction.log $OUT/construction.mp4 --keep-every 15 > $OUT/construction_encode.log 2>&1 &
  EP=$!
  tools/perf/gpu_run.sh 3600 $BIN --out=$OUT/construction --tag=rec --demo=runtime/spikes/s34_study/data/demo_mound_build.json --size=1512x982 > $OUT/construction.log 2>&1 < /dev/null
  wait $EP
  grep -q "DEMO end" $OUT/construction.log && [ -s $OUT/construction.mp4 ] && touch $OUT/construction.ok || echo construction >> $OUT/FAILED
fi
if [ ! -f $OUT/demo_stills.ok ]; then
  ac
  rm -rf $OUT/demo_stills
  tools/perf/gpu_run.sh 900 $BIN --out=$OUT/demo_stills --tag=demo --demo=runtime/spikes/s34_study/data/demo_mound_build.json --demo-stills > $OUT/demo_stills.log 2>&1 < /dev/null
  grep -q "DEMO end" $OUT/demo_stills.log && touch $OUT/demo_stills.ok || echo demo_stills >> $OUT/FAILED
fi
# 5. Real time on the Mac's screen, interleaved before/after (A B A B), 20 s each of idle, moving
#    and editing, at the owner's display setting (3600 x 2338 drawable, 120 Hz ProMotion).
#    A: the window as first built (two frames in flight, state sampled before the drawable wait,
#       a copy pass to the screen, the edit's upload on the frame loop) and the serial rebuild.
#    B: this build's defaults (one frame in flight, late sampling, direct present, upload prepared
#       on the worker) and the parallel rebuild.
for r in A1 B1 A2 B2; do
  if [ -f $OUT/win_$r.ok ]; then continue; fi
  ac
  case $r in
    A*) S34_SERIAL=1 runtime/spikes/s34_study/tools/window_run.sh $OUT/window win_$r --seconds=20 --scenarios=idle,moving,editing --latency=2 --latch=early --present=blit --upload=main --worker-qos=default ;;
    B*) runtime/spikes/s34_study/tools/window_run.sh $OUT/window win_$r --seconds=20 --scenarios=idle,moving,editing ;;
  esac
  [ -s $OUT/window/win_${r}_summary.txt ] && touch $OUT/win_$r.ok || echo win_$r >> $OUT/FAILED
done
# 6. The settle sequences as video files (from the half-size frames).
if [ ! -f $OUT/seq_mp4.ok ] && [ -f $OUT/flip.ok ]; then
  python3 ${0:A:h}/encode_seq.py $OUT/flip flip $OUT/sequences > $OUT/seq_mp4.log 2>&1 && touch $OUT/seq_mp4.ok || echo seq_mp4 >> $OUT/FAILED
fi
touch $OUT/DONE
