#!/bin/zsh
# Serialize GPU work on this Mac and refuse to run on battery.
#
#   tools/perf/gpu_run.sh TIMEOUT_SECONDS COMMAND [ARGS...]
#
# Only one wrapped command runs at a time (lock: /tmp/tsw_gpu.lock), so a frame
# rate probe is never sampled while another capture is rendering. The command
# is killed after TIMEOUT_SECONDS. Exit 97: not on AC power. Exit 98: the lock
# was not free within 30 minutes.
#
# Why the AC check: on 2026-11-19 a long run on battery drained the Mac to an
# under-voltage shutdown, and frame rates measured while it throttled were void.
set -u
LOCK=/tmp/tsw_gpu.lock
LIMIT=$1; shift
if ! pmset -g batt | head -1 | grep -q "AC Power"; then
  echo "gpu_run: NOT ON AC POWER - refusing to run" >&2
  exit 97
fi
waited=0
until mkdir "$LOCK" 2>/dev/null; do
  holder=$(cat "$LOCK/pid" 2>/dev/null)
  if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
    rm -rf "$LOCK"   # stale lock from a dead holder
    continue
  fi
  waited=$((waited + 2))
  if [ $waited -ge 1800 ]; then
    echo "gpu_run: lock busy for 30 minutes (holder pid $holder)" >&2
    exit 98
  fi
  sleep 2
done
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT INT TERM
"$@" &
child=$!
( sleep "$LIMIT"; kill "$child" 2>/dev/null ) &
watchdog=$!
wait "$child"
rc=$?
kill "$watchdog" 2>/dev/null
exit $rc
