@echo off
cd /d "%~dp0"
cd ../game/bin/

echo ext debugger opened!
remedybg debug.rdbg
echo ext debugger closed!

REM -g -q for execute directly / close on finish 