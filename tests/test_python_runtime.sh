#!/usr/bin/env bash

# 统一的 Python 相关回归测试，覆盖 serve 推断、工具检测以及虚拟环境命令包装。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" && pwd)"
# shellcheck source=../bin/lib/runtime.sh
source "$SCRIPT_DIR/lib/runtime.sh"

pass=0
fail=0

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [ "$expected" = "$actual" ]; then
    printf '  ✓ %s\n' "$message"
    pass=$((pass + 1))
  else
    printf '  ✗ %s\n    期望: %s\n    实际: %s\n' "$message" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  local message="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    printf '  ✓ %s\n' "$message"
    pass=$((pass + 1))
  else
    printf '  ✗ %s\n    未找到: %s\n    实际: %s\n' "$message" "$needle" "$haystack"
    fail=$((fail + 1))
  fi
}

projects=()
mkproject() {
  local dir
  dir=$(mktemp -d)
  projects+=("$dir")
  printf '%s\n' "$dir"
}

cleanup() {
  if [ "${projects+x}" != x ]; then
    return
  fi

  for dir in "${projects[@]}"; do
    rm -rf "$dir"
  done
}
trap cleanup EXIT

printf '=== 虚拟环境命令包装 ===\n'
venv_cmd=$(venv_activate_and_run "/tmp/demo/.venv" "pip install -r requirements.txt")
assert_contains '. "/tmp/demo/.venv/bin/activate" && ' "$venv_cmd" 'venv_activate_and_run 使用 POSIX 点号'
assert_contains 'pip install -r requirements.txt' "$venv_cmd" 'venv_activate_and_run 保留原命令'

wrap_python=$(wrap_venv_command "/tmp/demo/.venv" "python manage.py runserver")
assert_equals '"/tmp/demo/.venv/bin/python" manage.py runserver' "$wrap_python" 'wrap_venv_command 替换 python 可执行文件'

wrap_flask=$(wrap_venv_command "/tmp/demo/.venv" "flask run --debug")
assert_equals '"/tmp/demo/.venv/bin/flask" run --debug' "$wrap_flask" 'wrap_venv_command 替换 flask 命令'

wrap_uvicorn=$(wrap_venv_command "/tmp/demo/.venv" "uvicorn")
assert_equals '"/tmp/demo/.venv/bin/uvicorn"' "$wrap_uvicorn" 'wrap_venv_command 处理无参数命令'

runtime_dir=$(mkproject)
python3 -m venv "$runtime_dir/.venv" > /dev/null
# shellcheck disable=SC2016
run_cmd=$(venv_activate_and_run "$runtime_dir/.venv" "python -c 'print(42)'")
if sh -c "$run_cmd" > /dev/null; then
  printf '  ✓ venv_activate_and_run 在 sh -c 下可执行\n'
  pass=$((pass + 1))
else
  printf '  ✗ venv_activate_and_run 在 sh -c 下执行失败\n'
  fail=$((fail + 1))
fi

printf '\n=== 工具与框架检测 ===\n'
poetry_dir=$(mkproject)
cat > "$poetry_dir/pyproject.toml" << 'TOML'
[tool.poetry]
name = "demo"
version = "0.1.0"
TOML
touch "$poetry_dir/poetry.lock"
touch "$poetry_dir/manage.py"

poetry_tool=$(detect_python_tool "$poetry_dir")
poetry_framework=$(detect_python_framework "$poetry_dir")
poetry_serve=$(generate_python_serve_cmd "$poetry_dir" "$poetry_tool" "$poetry_framework" "")
poetry_install=$(generate_python_install_cmd "$poetry_dir" "$poetry_tool" 0)

assert_equals 'poetry' "$poetry_tool" 'Poetry 项目识别工具'
assert_equals 'django' "$poetry_framework" 'Poetry 项目识别 Django'
assert_equals 'poetry run python manage.py runserver' "$poetry_serve" 'Poetry Django 服务命令'
assert_equals 'poetry install --sync' "$poetry_install" 'Poetry 安装命令'

uv_dir=$(mkproject)
cat > "$uv_dir/main.py" << 'PY'
from fastapi import FastAPI
app = FastAPI()
PY
touch "$uv_dir/uv.lock"

uv_tool=$(detect_python_tool "$uv_dir")
uv_framework=$(detect_python_framework "$uv_dir")
uv_serve=$(generate_python_serve_cmd "$uv_dir" "$uv_tool" "$uv_framework" "")
uv_install=$(generate_python_install_cmd "$uv_dir" "$uv_tool" 0)

assert_equals 'uv' "$uv_tool" 'uv 项目识别工具'
assert_equals 'fastapi' "$uv_framework" 'uv 项目识别 FastAPI'
assert_equals 'uv run uvicorn main:app --reload' "$uv_serve" 'uv FastAPI 服务命令'
assert_equals 'uv venv && uv sync' "$uv_install" 'uv 安装命令'

pip_dir=$(mkproject)
cat > "$pip_dir/app.py" << 'PY'
from flask import Flask
app = Flask(__name__)
PY
touch "$pip_dir/requirements.txt"
python3 -m venv "$pip_dir/.venv" > /dev/null

pip_tool=$(detect_python_tool "$pip_dir")
pip_framework=$(detect_python_framework "$pip_dir")
pip_venv=$(detect_python_venv "$pip_dir")
pip_serve=$(generate_python_serve_cmd "$pip_dir" "$pip_tool" "$pip_framework" "$pip_dir/.venv")
pip_install=$(generate_python_install_cmd "$pip_dir" "$pip_tool" 1)
expected_pip_serve="\"$pip_dir/.venv/bin/flask\" run --debug"

assert_equals 'pip' "$pip_tool" 'pip 项目识别工具'
assert_equals 'flask' "$pip_framework" 'pip 项目识别 Flask'
assert_equals '.venv' "$pip_venv" 'pip 项目识别虚拟环境目录'
assert_equals "$expected_pip_serve" "$pip_serve" 'pip Flask 服务命令'
assert_equals '. ".venv/bin/activate" && pip install -r requirements.txt' "$pip_install" 'pip 安装命令'

conda_dir=$(mkproject)
cat > "$conda_dir/environment.yml" << 'YAML'
name: demo-conda
channels:
  - conda-forge
dependencies:
  - python>=3.10
  - fastapi
YAML
cat > "$conda_dir/main.py" << 'PY'
from fastapi import FastAPI
app = FastAPI()
PY

conda_tool=$(detect_python_tool "$conda_dir")
conda_install=$(generate_python_install_cmd "$conda_dir" "$conda_tool" 0)
conda_serve=$(generate_python_serve_cmd "$conda_dir" "$conda_tool" "fastapi" "")

assert_equals 'conda' "$conda_tool" 'Conda 项目识别工具'
assert_equals 'conda env update --file environment.yml --prune || conda env create --file environment.yml' "$conda_install" 'Conda 安装命令'
assert_equals 'conda run --live-stream -n "demo-conda" uvicorn main:app --reload' "$conda_serve" 'Conda 服务命令'

printf '\n=== 框架及兜底逻辑 ===\n'
manage_dir=$(mkproject)
cat > "$manage_dir/manage.py" << 'PY'
print("hello")
PY
assert_equals 'python manage.py runserver' "$(infer_serve_command "$manage_dir")" 'manage.py 项目兜底 serve 命令'

app_dir=$(mkproject)
cat > "$app_dir/app.py" << 'PY'
print("hello")
PY
assert_equals 'python app.py' "$(infer_serve_command "$app_dir")" '纯 app.py 项目兜底 serve 命令'

fastapi_subdir=$(mkproject)
mkdir -p "$fastapi_subdir/app"
cat > "$fastapi_subdir/app/main.py" << 'PY'
from fastapi import FastAPI
app = FastAPI()
PY
assert_equals 'app/main.py' "$(find_python_app_entry "$fastapi_subdir" "fastapi")" 'FastAPI 应用入口在 app/main.py'
assert_equals 'uvicorn app.main:app --reload' "$(generate_python_serve_cmd "$fastapi_subdir" "pip" "fastapi" "")" 'FastAPI 子目录服务命令'

printf '\n'
if [ "$fail" -eq 0 ]; then
  printf '✅ Python 回归测试全部通过，共 %d 项。\n' "$pass"
else
  printf '❌ Python 回归测试存在失败：%d 通过，%d 失败。\n' "$pass" "$fail"
  exit 1
fi
