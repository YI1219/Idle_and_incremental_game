#!/bin/zsh
# Renders the review set of the natural-look package: stills, edit test and benches.
#
# Run from anywhere, detached, on the Mac:
#   nohup art/lookdev/20261123_natural/checks/render_review.sh [OUT] > /tmp/render_review.log 2>&1 &
# OUT defaults to art/lookdev/20261123_natural/final2. A run that finished leaves OUT/<name>.ok
# and is skipped the next time, so the script can be started again after an interruption.
# OUT/DONE is written when everything has been tried; OUT/FAILED lists runs that did not finish.
set -u
cd ${0:A:h}/../../../..
OUT=${1:-art/lookdev/20261123_natural/final2}
REF=runtime/data/reference
SHOT=runtime/spikes/s34_study/tools/shot.sh
V12=game,whole,reverse,close,cliff_close,side_106,side_286,foot_front,foot_reverse,overview,terrace_close,outer_hull
mkdir -p $OUT
rm -f $OUT/DONE $OUT/FAILED

run() {  # run NAME SECONDS ARGS...
  local name=$1 secs=$2; shift 2
  if [ -f $OUT/$name.ok ]; then echo "skip $name"; return; fi
  rm -rf $OUT/$name
  tools/perf/gpu_run.sh $secs $SHOT $OUT/$name --tag=$name --metrics=$OUT/$name/metrics.json "$@" > $OUT/$name.log 2>&1
  local rc=$?
  echo "$(date +%H:%M:%S) $name rc=$rc"
  # shot.sh ends in a pipe, so its status says little: a run counts only if it printed a
  # frame or an edit line and did not panic.
  if [ $rc -eq 0 ] && grep -q -E "^FRAME|^EDIT" $OUT/$name.log && ! grep -q "panicked" $OUT/$name.log; then touch $OUT/$name.ok; else echo $name >> $OUT/FAILED; fi
}

L7301="--layout=$REF/layout_7301_0.json --seed=7301 --body=karst"
R7301="--layout=$REF/layout_7301_0_ramps.json --seed=7301 --body=karst"
L2104="--layout=$REF/layout_2104_0.json --seed=2104 --body=karst"
R2104="--layout=$REF/layout_2104_0_ramps.json --seed=2104 --body=karst"
L4242="--layout=$REF/layout_4242_1.json --seed=4242 --body=karst"
R4242="--layout=$REF/layout_4242_1_slope.json --seed=4242 --body=karst"
L913="--layout=$REF/layout_913_2.json --seed=913 --body=karst"
SYN="--synthetic=4096 --seed=7301 --body=karst"
MOVING="--scale=1 --fxaa"

# Stills, resting mode (2x supersampling).
run n_7301        900 ${=L7301} --views=$V12,ramp1,ramp2,ramp3
run n_7301_ramps  900 ${=R7301} --views=$V12,ramp1,ramp2,ramp3
run n_2104        900 ${=L2104} --views=$V12,diag1,diag2
run n_diag        900 ${=R2104} --views=$V12,diag1,diag2
run n_4242        900 ${=L4242} --views=$V12,slope
run n_slope       900 ${=R4242} --views=$V12,slope
run n_913         900 ${=L913}  --views=$V12
run n_dusk        900 ${=L7301} --hour=dusk  --views=$V12
run n_night       900 ${=L7301} --hour=night --views=$V12
run n_dusk_ramps  600 ${=R7301} --hour=dusk  --views=whole,game,terrace_close,ramp1,ramp2
run n_night_ramps 600 ${=R7301} --hour=night --views=whole,game,terrace_close,ramp1,ramp2
run n_trio        600 ${=L7301} --scene=trio --views=wallpaper
run n_trio_dusk   600 ${=L7301} --scene=trio --hour=dusk  --views=wallpaper
run n_trio_night  600 ${=L7301} --scene=trio --hour=night --views=wallpaper
run n_syn4096       600 ${=SYN} --views=whole,game,overview
run n_syn4096_ramps 600 ${=SYN} --synthetic-ramps --views=whole,game,overview

# Stills, moving-camera mode (one sample per pixel and FXAA).
run n_moving       900 ${=L7301} ${=MOVING} --views=$V12
run n_moving_ramps 600 ${=R7301} ${=MOVING} --views=game,terrace_close,ramp1,ramp2,ramp3

# Edit locality: scripted strokes on the five islands.
run edit_7301 600 ${=L7301} --edit-test --views=whole
run edit_2104 600 ${=L2104} --edit-test --views=whole
run edit_4242 600 ${=L4242} --edit-test --views=whole
run edit_913  600 ${=L913}  --edit-test --views=whole
run edit_syn  600 ${=SYN}   --edit-test --views=whole
: > $OUT/edit_test.log
for n in edit_7301 edit_2104 edit_4242 edit_913 edit_syn; do
  echo "== $n" >> $OUT/edit_test.log
  grep -E "^form|^EDIT|^RAMP" $OUT/$n.log >> $OUT/edit_test.log
done

# Benches last: 120 frames per view with the camera orbiting. They are only fair on an idle
# machine, so the load and the busiest processes are recorded beside them.
{ date; uptime; ps -Ao pcpu,comm -r | head -6; } > $OUT/load_at_benches.txt 2>&1
run bench_moving              900 ${=L7301} ${=MOVING} --bench --views=$V12
run bench_moving_ramps         900 ${=R7301} ${=MOVING} --bench --views=$V12
run bench_moving_trio          600 ${=L7301} --scene=trio ${=MOVING} --bench --views=wallpaper
run bench_moving_syn4096       600 ${=SYN} ${=MOVING} --bench --views=whole,game
run bench_moving_syn4096_ramps 600 ${=SYN} --synthetic-ramps ${=MOVING} --bench --views=whole,game
run bench_rest                 600 ${=L7301} --bench --views=whole,game

date > $OUT/DONE
echo "review set finished"
