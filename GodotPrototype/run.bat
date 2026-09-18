@echo off
setlocal EnableDelayedExpansion
rem ------------------------------------------------------------------
rem  Godot 4.7 launcher. Finds Godot automatically so nothing needs to be
rem  edited when the project moves to another PC. Search order:
rem    1) GODOT env var (explicit override)
rem    2) godot / godot_console on PATH, or the WinGet Links folder
rem    3) WinGet package folders (Standard or Mono)
rem    4) Common manual locations: C:\Godot, %USERPROFILE%\Godot, ..\Tools\Godot
rem ------------------------------------------------------------------
set "GODOT_EXE="

if defined GODOT if exist "%GODOT%" set "GODOT_EXE=%GODOT%"

if not defined GODOT_EXE for %%C in (godot.exe godot_console.exe) do (
  if not defined GODOT_EXE for /f "delims=" %%P in ('where %%C 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%P"
)
if not defined GODOT_EXE if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" set "GODOT_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe"

if not defined GODOT_EXE for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*") do (
  if not defined GODOT_EXE for /f "delims=" %%P in ('dir /b /s /a-d "%%~D\Godot_v4*_win64.exe" 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%P"
)

if not defined GODOT_EXE for %%D in ("C:\Godot" "%USERPROFILE%\Godot" "%ProgramFiles%\Godot" "%~dp0..\Tools\Godot") do (
  if not defined GODOT_EXE if exist "%%~D\" for /f "delims=" %%P in ('dir /b /s /a-d "%%~D\Godot_v4*_win64.exe" 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%P"
)

if not defined GODOT_EXE (
  echo [run.bat] Godot 4.x executable not found.
  echo   - Run setup.bat to install it with WinGet, or
  echo   - set the GODOT env var to the Godot exe path, e.g.
  echo     set GODOT=D:\Tools\Godot_v4.7.2-stable_win64.exe
  pause
  exit /b 1
)

echo [run.bat] Godot: !GODOT_EXE!
set "PROJ=%~dp0"
set "PROJ=!PROJ:~0,-1!"
rem Godot caches class_name registrations and texture imports in .godot/,
rem which is per-PC (gitignored). After a git pull that adds scripts or
rem assets, that cache is stale and the game fails with "Identifier not
rem declared" / "Compilation failed". A headless import pass rebuilds it;
rem it takes a few seconds when the cache is warm, so always run it.
if not exist "!PROJ!\.godot\" (
  echo [run.bat] First run on this PC - importing project ^(one time, may take a while^)...
) else (
  echo [run.bat] Refreshing import cache...
)
"!GODOT_EXE!" --path "!PROJ!" --headless --import >nul 2>nul
"!GODOT_EXE!" --path "!PROJ!" %*