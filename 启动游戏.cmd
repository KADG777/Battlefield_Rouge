@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set "game_godot="
if defined GODOT_EXE (
  if exist "%GODOT_EXE%" set "game_godot=%GODOT_EXE%"
)
if not defined game_godot (
  where godot >nul 2>nul
  if not errorlevel 1 set "game_godot=godot"
)
if not defined game_godot (
  echo 未找到 Godot。请安装 Godot 4.7.2，并设置 GODOT_EXE 为引擎完整路径，或将 godot 加入 PATH。
  echo 也可在 Godot 项目管理器中导入本目录 project.godot，再按 F5 运行。
  pause
  exit /b 1
)
"%game_godot%" --headless --editor --path "%~dp0." --import
if errorlevel 1 (
  echo 素材导入失败，请用 Godot 4.7.2 编辑器打开工程查看输出。
  pause
  exit /b 1
)
start "" "%game_godot%" --path "%~dp0."
