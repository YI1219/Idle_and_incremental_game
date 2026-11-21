#!/bin/zsh
# Render the ID stills and count fragments for one label and several layouts.
# Usage: rock_metric.sh LABEL [seed:preset ...]   (default: the four held layouts)
set -u
cd /Users/yi/Projects/games/the-scroll-within || exit 1
LABEL=$1; shift
LAYOUTS=("$@")
[ ${#LAYOUTS[@]} -eq 0 ] && LAYOUTS=(7301:0 2104:0 4242:1 913:2)
C=art/lookdev/20261119_rock_shapes/checks
if ! pmset -g batt | head -1 | grep -q "AC Power"; then echo "NOT ON AC POWER - refusing to run"; exit 2; fi
for L in "${LAYOUTS[@]}"; do
  S=${L%%:*}; P=${L##*:}
  OUT=art/lookdev/20261119_rock_shapes/ids_${LABEL}_$S
  rm -rf "$OUT"
  /opt/homebrew/bin/godot --path . --script res://$C/id_render.gd -- --out=res://$OUT --seed=$S --preset=$P > $C/id_${LABEL}_$S.log 2>&1 &
  pid=$!; (sleep 200; kill $pid 2>/dev/null) & wd=$!; wait $pid; rc=$?; kill $wd 2>/dev/null
  errs=$(grep -cE "SCRIPT ERROR|^ERROR" $C/id_${LABEL}_$S.log)
  printf "seed %s preset %s exit=%s errors=%s " "$S" "$P" "$rc" "$errs"
  python3 $C/fragment_metric.py "$OUT" --overlay | tail -1
done
