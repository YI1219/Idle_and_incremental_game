#!/bin/zsh
# Like-for-like frame cost under whatever load the Mac has right now: the build of the first
# owner package (commit e32b851) and the current tree, benchmarked back to back, twice.
#
#   nohup art/lookdev/20261123_natural/checks/bench_control.sh > /tmp/bench_control.log 2>&1 &
#
# Results land in art/lookdev/20261123_natural/final2/control/ (<name>.log has the BENCH lines,
# <name>.load the load average when it started). The older build lives in a temporary git
# worktree at /tmp/tsw_wt_e32 with its own target directory; remove it afterwards with
#   git worktree remove --force /tmp/tsw_wt_e32
set -u
REPO=${0:A:h}/../../../..
REPO=${REPO:A}
WT=/tmp/tsw_wt_e32
OUT=$REPO/art/lookdev/20261123_natural/final2/control
V12=game,whole,reverse,close,cliff_close,side_106,side_286,foot_front,foot_reverse,overview,terrace_close,outer_hull
mkdir -p $OUT
rm -f $OUT/DONE
cd $REPO
if [ ! -d $WT ]; then git worktree add --detach $WT e32b851 > $OUT/worktree.log 2>&1; fi
for d in $REPO/runtime/data/reference/scene_*; do ln -sfn $d $WT/runtime/data/reference/${d:t}; done
(cd $WT/runtime && cargo build --release --offline -p s34_study > $OUT/build_first.log 2>&1; echo "build rc=$?" >> $OUT/build_first.log)

bench() {  # bench NAME ROOT ARGS...
  local name=$1 root=$2; shift 2
  { date; uptime; } > $OUT/$name.load
  rm -rf $OUT/$name
  (cd $root && tools/perf/gpu_run.sh 900 runtime/spikes/s34_study/tools/shot.sh $OUT/$name --tag=$name "$@" > $OUT/$name.log 2>&1)
  echo "$(date +%H:%M:%S) $name: $(grep -c '^BENCH' $OUT/$name.log) bench lines"
}

ONE="--layout=runtime/data/reference/layout_7301_0.json --seed=7301 --body=karst --scale=1 --fxaa --bench --views=$V12"
BIG="--synthetic=4096 --seed=7301 --body=karst --scale=1 --fxaa --bench --views=whole,game"
bench first_7301   $WT   ${=ONE}
bench now_7301     $REPO ${=ONE}
bench first_syn    $WT   ${=BIG}
bench now_syn      $REPO ${=BIG}
bench first_7301_b $WT   ${=ONE}
bench now_7301_b   $REPO ${=ONE}
bench first_syn_b  $WT   ${=BIG}
bench now_syn_b    $REPO ${=BIG}
rm -rf $OUT/*/small $OUT/*/*.png
date > $OUT/DONE
echo "control finished"
