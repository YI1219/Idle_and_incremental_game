#!/bin/zsh
set -e
cd -- "${0:A:h}"
if [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  exec /Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/terrain_editor.tscn
fi
exec godot --path . res://scenes/terrain_editor.tscn
