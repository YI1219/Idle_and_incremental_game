#!/bin/zsh
# ablate_all.sh : cost breakdown of the current frame at three real pixel sizes.
# One live scene per size; every variant is applied, warmed 1.5 s, sampled 4 s and
# restored; the list is replayed forward then backward (probe_ablate.gd).
cd /Users/yi/Projects/games/the-scroll-within
P=art/lookdev/20261121_perf_stack
WATER='hideshader:water.gdshader+waterfall.gdshader+foam.gdshader+waterfall_mist.gdshader'
STONE='hideshader:cliff_column.gdshader+cliff.gdshader+stone_mantle.gdshader+cliff_rock.gdshader'
GROUND='hideshader:ground.gdshader+rim_green.gdshader+lake_bed.gdshader+shore.gdshader'
PLANTS='hideshader:foliage_cards.gdshader+decor_vertex_color.gdshader'
V="base,native,msaa0,msaa4,ssao0,ssil0,ssao0&ssil0,dof0,glow0,adj0,fog0,shadow0,softq0,fill0,bg0,motes0,unshaded,nogeo,skycolor,noproc,nowater,hideshader:grass_blades.gdshader,hideshader:distant_mountain.gdshader,hideshader:cloud_deck.gdshader,$WATER,$STONE,$GROUND,$PLANTS,scale0.67,scale0.5,msaa0&ssao0&ssil0&dof0&glow0,msaa0&ssao0&ssil0&dof0&glow0&shadow0,msaa0&ssao0&ssil0&dof0&glow0&shadow0&hideshader:grass_blades.gdshader"
sizes=("$@"); [ ${#sizes} -eq 0 ] && sizes=(1920x1080 2560x1440 3840x2160)
for size in $sizes; do
  uptime > $P/data/ablate_$size.load
  tools/perf/gpu_run.sh 1200 /opt/homebrew/bin/godot --path . --disable-vsync --script res://$P/checks/probe_ablate.gd -- "--variants=$V" --rounds=2 --size=$size --out=$PWD/$P/data/ablate_$size.json > $P/data/ablate_$size.log 2>&1 < /dev/null
  echo "$size rc=$? results=$(grep -c '^RESULT' $P/data/ablate_$size.log) errors=$(grep -cE 'SCRIPT ERROR|^ERROR' $P/data/ablate_$size.log)"
done
echo ABLATE_DONE
