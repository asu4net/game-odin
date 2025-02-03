#!/bin/bash

cd game/bin

if [ ! -f "game" ]; then
    cd ../../
    ./build.sh
    cd game/bin
fi

echo "Running game..."
./game
echo "Terminated!"
