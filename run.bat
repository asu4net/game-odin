cd game/bin

IF NOT EXIST "game.exe" (
    cd ../../
    call build.bat
)

cd game/bin
game.exe