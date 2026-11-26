#!/bin/zsh
# Renders and measures the owner-review set of round k5b (owner review of 2026-11-26): unloading a
# raised block as retract-then-merge, edits that stay local (no coupled changes, no restart), rock
# walls without vertical stripes, and the construction recording with the new build.
#
#   nohup art/lookdev/20261127_k5b/checks/render_k5b.sh [OUT] > /tmp/render_k5b.log 2>&1 &
# OUT defaults to art/lookdev/20261127_k5b. "Before" runs use the build of backup-before-k5b-20261127
# (dd9a597) in the worktree /tmp/tsw_k5/wt_old (OLD below). Finished steps leave OUT/<name>.ok.
set -u
cd ${0:A:h}/../../../..
OUT=${1:-art/lookdev/20261127_k5b}
NEW=runtime/target/release/s34_study
OLD=${OLD:-/tmp/tsw_k5/wt_old/runtime/target/release/s34_study}
CHK=${0:A:h}
mkdir -p $OUT
rm -f $OUT/DONE $OUT/FAILED
L=(--layout=runtime/data/reference/layout_7301_0.json --seed=7301 --body=karst)
ac() { pmset -g batt | head -1 | grep -q "AC Power" || { echo "not on AC power" >> $OUT/FAILED; exit 3; } }
step() {  # step NAME SECONDS BIN ARGS... (frames into OUT/NAME)
  local name=$1 secs=$2 bin=$3; shift 3
  if [ -f $OUT/$name.ok ]; then echo "skip $name"; return; fi
  ac
  rm -rf $OUT/$name; mkdir -p $OUT/$name
  tools/perf/gpu_run.sh $secs $bin --out=$OUT/$name --tag=$name "$@" > $OUT/$name.log 2>&1 < /dev/null
  if grep -q "^FRAME\|^EDIT\|DEMO end" $OUT/$name.log && ! grep -q panicked $OUT/$name.log; then touch $OUT/$name.ok; else echo $name >> $OUT/FAILED; fi
  echo "$(date +%H:%M:%S) $name"
}
WHOLE="-2,0,-1,16,30,64"

# (c) Rock walls: the same views before and after, full size.
step walls_before 900 $OLD $L --views=foot_front,cliff_close,reverse,side_286,outer_hull,whole
step walls 900 $NEW $L --views=foot_front,cliff_close,reverse,side_286,outer_hull,whole
step demo_before 900 $OLD --demo=runtime/spikes/s34_study/data/demo_mound_build.json --demo-stills
step demo_after 900 $NEW --demo=runtime/spikes/s34_study/data/demo_mound_build.json --demo-stills
# (a) Unloading a raised block, and the other lowering edits, 30 frames a second at half size.
step motion_before 1800 $OLD $L --settle=unraise,lower,ramp --size=1512x982
step motion 1800 $NEW $L --settle=unload,unraise,lower,ramp --size=1512x982
# (b) Coupling: erase and expand seen whole, before and after the edit, both builds; the new build's
#     triangle check frames and numbers.
for b in before after; do
  bin=$NEW; [ $b = before ] && bin=$OLD
  if [ ! -f $OUT/couple_$b.ok ]; then
    ac; rm -rf $OUT/couple_$b; mkdir -p $OUT/couple_$b
    S34_SETTLE_CAMERA=$WHOLE tools/perf/gpu_run.sh 900 $bin --out=$OUT/couple_$b --tag=front $L --settle=erase,expand --settle-times=1.5 > $OUT/couple_$b.log 2>&1 < /dev/null
    S34_SETTLE_CAMERA="-2,0,-1,196,30,64" tools/perf/gpu_run.sh 900 $bin --out=$OUT/couple_$b --tag=back $L --settle=erase,expand --settle-times=1.5 >> $OUT/couple_$b.log 2>&1 < /dev/null
    grep -q "^FRAME" $OUT/couple_$b.log && touch $OUT/couple_$b.ok || echo couple_$b >> $OUT/FAILED
  fi
done
if [ ! -f $OUT/diff.ok ]; then
  ac; rm -rf $OUT/diff; mkdir -p $OUT/diff
  S34_DIFF=1 tools/perf/gpu_run.sh 1200 $NEW --out=$OUT/diff --tag=diff $L --settle=erase,expand,unload,raise,lower,ramp,remove,place,fill,drain --settle-times=1.5 --size=1512x982 > $OUT/diff.log 2>&1 < /dev/null
  S34_DIFF=1 S34_SETTLE_CAMERA=$WHOLE tools/perf/gpu_run.sh 900 $NEW --out=$OUT/diff --tag=diffwhole $L --settle=erase,expand --settle-times=1.5 --size=1512x982 >> $OUT/diff.log 2>&1 < /dev/null
  grep -q "^DIFF" $OUT/diff.log && touch $OUT/diff.ok || echo diff >> $OUT/FAILED
fi
# Real time on the Mac's screen with an erase edit every 2.5 s: the old window code and build, then
# this build (20 s each of idle and editing at the owner's display setting).
for r in before after; do
  if [ -f $OUT/win_$r.ok ]; then continue; fi
  ac
  if [ $r = before ]; then
    (cd /tmp/tsw_k5/wt_old && runtime/spikes/s34_study/tools/window_run.sh $OLDPWD/$OUT/window win_$r --seconds=20 --scenarios=idle,editing --edit=erase)
  else
    runtime/spikes/s34_study/tools/window_run.sh $OUT/window win_$r --seconds=20 --scenarios=idle,editing --edit=erase
  fi
  [ -s $OUT/window/win_${r}_summary.txt ] && touch $OUT/win_$r.ok || echo win_$r >> $OUT/FAILED
done
# The construction from one mound, recorded with this build.
if [ ! -f $OUT/construction.ok ]; then
  ac; rm -rf $OUT/construction; mkdir -p $OUT/construction
  python3 -u $CHK/encode.py $OUT/construction rec $OUT/construction.log $OUT/construction.mp4 --keep-every 15 > $OUT/construction_encode.log 2>&1 &
  EP=$!
  tools/perf/gpu_run.sh 3600 $NEW --out=$OUT/construction --tag=rec --demo=runtime/spikes/s34_study/data/demo_mound_build.json --size=1512x982 > $OUT/construction.log 2>&1 < /dev/null
  wait $EP
  grep -q "DEMO end" $OUT/construction.log && [ -s $OUT/construction.mp4 ] && touch $OUT/construction.ok || echo construction >> $OUT/FAILED
fi
# Checks: hole view over the twelve review views, edit locality.
step parts 1200 $NEW $L --views=all --debug=parts --grass=off --size=1512x982
step edit 600 $NEW $L --views=none --edit-test
# Videos of the motion (before and after).
for m in motion_before motion; do
  if [ -f $OUT/$m.ok ] && [ ! -f $OUT/${m}_mp4.ok ]; then
    python3 $CHK/encode_seq.py $OUT/$m $m $OUT/${m}_mp4 > $OUT/${m}_mp4.log 2>&1 && touch $OUT/${m}_mp4.ok || echo ${m}_mp4 >> $OUT/FAILED
  fi
done
touch $OUT/DONE
