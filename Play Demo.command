#!/bin/zsh
set -e
cd -- "${0:A:h}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v godot >/dev/null; then
  print "Godot was not found. Install Godot 4.7 or newer, or open this folder in the Godot editor."
  read -r "?Press Return to close"
  exit 1
fi
godot --headless --editor --path . --import --log-file /tmp/yunlu-demo-import.log
exec godot --path . res://scenes/play.tscn
