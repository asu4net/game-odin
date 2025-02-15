@echo off

cd game/bin

IF NOT EXIST "game.exe" (
    cd ../../
    call build.bat
    cd game/bin
    goto RunGame
)

:RunGame
@echo Running game...
game.exe
@echo Terminated!