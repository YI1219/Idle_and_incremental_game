#!/bin/zsh
# ablate_light.sh SIZE K : candidate settings for a light tier, GPU-bound (probe_ablate_k.gd).
cd /Users/yi/Projects/games/the-scroll-within
P=art/lookdev/20261121_perf_stack
V="base,msaa0,msaa0&smaa,msaa0&fxaa,shadow2k,splits2,shadow2k&splits2,grassshadow0,foliageshadow0,hideshader:foliage_cards.gdshader,hideshader:decor_vertex_color.gdshader,noshadowcast,ssil0,ssao0&ssil0,msaa0&smaa&ssil0,msaa0&smaa&ssao0&ssil0,msaa0&smaa&ssao0&ssil0&dof0,msaa0&smaa&ssao0&ssil0&dof0&shadow2k&splits2,msaa0&smaa&ssao0&ssil0&dof0&shadow2k&splits2&scale0.67"
size=$1; k=$2
uptime > $P/data/light_k${k}_$size.load
tools/perf/gpu_run.sh 1500 /opt/homebrew/bin/godot --path . --disable-vsync --script res://$P/checks/probe_ablate_k.gd -- "--variants=$V" --rounds=2 --size=$size --k=$k --out=$PWD/$P/data/light_k${k}_$size.json > $P/data/light_k${k}_$size.log 2>&1 < /dev/null
echo "$size k=$k rc=$? results=$(grep -c '^RESULT' $P/data/light_k${k}_$size.log) errors=$(grep -cE 'SCRIPT ERROR|^ERROR' $P/data/light_k${k}_$size.log)"
