#!/bin/zsh
# Renders study frames and makes reduced copies for quick review.
#   tools/perf/gpu_run.sh 300 runtime/spikes/s34_study/tools/shot.sh OUT_DIR ARGS...
# Frames land in OUT_DIR, reduced copies (1300 px wide) in OUT_DIR/small. With
# CROP="Y X" set, a 1300 x 850 crop at native pixels is written beside each reduced copy.
set -u
OUT=$1; shift
HERE=${0:A:h}
BIN=$HERE/../../../target/release/s34_study
mkdir -p $OUT/small
$BIN --out=$OUT "$@" | tee -a $OUT/run.log | grep -E "^island|^form|^EDIT|^PROPS|^GRASS|^BENCH|^STATS|^FRAME" | while read -r line; do
  echo "$line"
  if [[ $line == FRAME* ]]; then
    file=${line#FRAME }
    sips -Z 1300 $file --out $OUT/small/${file:t} > /dev/null 2>&1
    if [ -n "${CROP:-}" ]; then
      sips -c 850 1300 --cropOffset ${=CROP} $file --out $OUT/small/${file:t:r}_crop.png > /dev/null 2>&1
    fi
  fi
done
