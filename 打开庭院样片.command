#!/bin/zsh
cd "$(dirname "$0")" || exit 1
exec /Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/courtyard_study.tscn
