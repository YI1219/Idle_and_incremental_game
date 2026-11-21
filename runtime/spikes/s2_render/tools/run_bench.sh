#!/bin/zsh
# Spike S2 bench set. Run through tools/perf/gpu_run.sh from the repository root:
#   tools/perf/gpu_run.sh 900 runtime/spikes/s2_render/tools/run_bench.sh OUT_DIR
set -u
OUT=${1:-/tmp/tsw_s2}
HERE=${0:A:h}
BIN=$HERE/../../../target/release/s2_render
mkdir -p $OUT
run() { # name, then arguments
  local name=$1; shift
  echo "== $name: $*"
  $BIN "$@" --out=$OUT/$name.json | grep -E "^scene|^shadow|^RESULT|^REBUILD"
}
# The gate resolution (the panel) and the size a full-screen window is asked to fill today.
run gate_3024 --size=3024x1964 --png=$OUT/gate_3024
run desktop_3600 --size=3600x2338
# Cross-check of the timing method: wait for the GPU after every single frame.
S2_BATCH=1 run gate_3024_sync --size=3024x1964 --rounds=2
# Scaling checks: four times the pixels; three times the scattered detail.
run quad_6048 --size=6048x3928 --rounds=2
run detail3_3024 --size=3024x1964 --detail=3
# One default-size island alone, for comparison with Godot's 623-cell scene.
run starter_3024 --size=3024x1964 --scene=starter
