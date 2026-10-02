#!/bin/zsh
set -e
game_dir="$(cd -- "$(dirname -- "$0")" && pwd)/prototype"
godot_bin="/Applications/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$godot_bin" ]]; then
  godot_bin="$(command -v godot || command -v godot4 || true)"
fi
if [[ -z "$godot_bin" ]]; then
  print "请安装 Godot 4，然后用它导入 prototype/project.godot。"
  read -r "reply?按回车关闭…"
  exit 1
fi
exec "$godot_bin" --path "$game_dir"
