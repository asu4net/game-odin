@echo off

cd game/bin

IF NOT EXIST "game.exe" (
    cd ../../
    call build.bat
)

@echo running...
game.exe
@echo terminated!