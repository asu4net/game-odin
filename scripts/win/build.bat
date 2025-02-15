@echo off
echo building..
odin build ./game -debug -out:game/bin/game.exe -collection:engine=./engine
echo finished!