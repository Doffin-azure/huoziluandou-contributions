#!/bin/zsh
set -u
project_dir="${0:A:h:h}"
python_bin=""
for candidate in python3 /opt/homebrew/bin/python3 /usr/local/bin/python3 "$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"; do
  if command -v "$candidate" >/dev/null 2>&1; then python_bin="$candidate"; break; fi
done
if [[ -z "$python_bin" ]]; then
  print '未找到 Python 3。请先安装 Python 3，再重新导入。'
  import_exit=1
else
  "$python_bin" "$project_dir/tools/achievements/import_achievements.py" --restore
  import_exit=$?
fi
if [[ -t 0 ]]; then read -r '?按回车关闭窗口'; fi
exit "$import_exit"
