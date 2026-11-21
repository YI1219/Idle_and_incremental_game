#!/bin/zsh
# ablate_k.sh SIZE K : GPU-bound cost breakdown (probe_ablate_k.gd), frame time divided by K.
cd /Users/yi/Projects/games/the-scroll-within
P=art/lookdev/20261121_perf_stack
WATER='hideshader:water.gdshader+waterfall.gdshader+foam.gdshader+waterfall_mist.gdshader'
STONE='hideshader:cliff_column.gdshader+cliff.gdshader+stone_mantle.gdshader+cliff_rock.gdshader'
GROUND='hideshader:ground.gdshader+rim_green.gdshader+lake_bed.gdshader+shore.gdshader'
PLANTS='hideshader:foliage_cards.gdshader+decor_vertex_color.gdshader'
POST='msaa0&ssao0&ssil0&dof0&glow0'
V="base,native,msaa0,msaa4,ssao0,ssil0,ssao0&ssil0,dof0,glow0,fog0,shadow0,softq0,fill0,motes0,unshaded,nogeo,skycolor,hideshader:grass_blades.gdshader,hideshader:distant_mountain.gdshader,hideshader:cloud_deck.gdshader,$WATER,$STONE,$GROUND,$PLANTS,scale0.67,scale0.5,$POST,$POST&shadow0,$POST&shadow0&hideshader:grass_blades.gdshader,$POST&shadow0&hideshader:grass_blades.gdshader&hideshader:distant_mountain.gdshader,nogeo&$POST"
size=$1; k=$2
uptime > $P/data/ablate_k${k}_$size.load
tools/perf/gpu_run.sh 1500 /opt/homebrew/bin/godot --path . --disable-vsync --script res://$P/checks/probe_ablate_k.gd -- "--variants=$V" --rounds=2 --size=$size --k=$k --out=$PWD/$P/data/ablate_k${k}_$size.json > $P/data/ablate_k${k}_$size.log 2>&1 < /dev/null
echo "$size k=$k rc=$? results=$(grep -c '^RESULT' $P/data/ablate_k${k}_$size.log) errors=$(grep -cE 'SCRIPT ERROR|^ERROR' $P/data/ablate_k${k}_$size.log)"
