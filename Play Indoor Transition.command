#!/bin/zsh
set -e
cd -- "${0:A:h}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if command -v godot >/dev/null; then
  godot_bin="godot"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
  godot_bin="/Applications/Godot.app/Contents/MacOS/Godot"
else
  print "Godot was not found. Install Godot 4.7 or newer, or open project.godot in the Godot editor and press Play."
  read -r "?Press Return to close"
  exit 1
fi
exec "$godot_bin" --path .
