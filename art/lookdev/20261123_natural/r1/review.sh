#!/bin/zsh
# Review renders for round r1 of look n. Run from the repo root on the Mac.
set -u
R=art/lookdev/20261123_natural/r1
L=runtime/data/reference/layout_7301_0.json
S=runtime/spikes/s34_study/tools/shot.sh
G=tools/perf/gpu_run.sh
mkdir -p $R
run() { local name=$1; shift; mkdir -p $R/$name; $G 600 $S $R/$name --tag=$name --metrics=$R/$name/metrics.json "$@" > $R/$name.log 2>&1 < /dev/null; echo "$name rc=$?"; }
CROP="950 700" run n_7301 --layout=$L --seed=7301 --body=karst --look=n --views=game,whole,reverse,cliff_close,foot_reverse,terrace_close
run n_dusk --layout=$L --seed=7301 --body=karst --look=n --hour=dusk --views=whole,game
run n_night --layout=$L --seed=7301 --body=karst --look=n --hour=night --views=whole,game
run n_trio --layout=$L --seed=7301 --body=karst --look=n --scene=trio --views=wallpaper
run n_syn4096 --synthetic=4096 --seed=7301 --body=karst --look=n --views=whole,game
run bench_n --layout=$L --seed=7301 --body=karst --look=n --views=whole,game --bench
run bench_n_scale1 --layout=$L --seed=7301 --body=karst --look=n --views=whole,game --bench --scale=1
run bench_n_syn4096 --synthetic=4096 --seed=7301 --body=karst --look=n --views=whole,game --bench
run bench_n_noao --layout=$L --seed=7301 --body=karst --look=n --views=whole,game --bench --ssao=off
run bench_n_scale1_noao --layout=$L --seed=7301 --body=karst --look=n --views=whole,game --bench --scale=1 --ssao=off
run bench_n_noblur --layout=$L --seed=7301 --body=karst --look=n --views=whole,game --bench --ssao=noblur
