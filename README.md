# game-odin
 Just a game template written in odin lang

## Build
 - Download odin last version https://github.com/odin-lang/Odin/releases
 - Add the odin compiler directory to the **PATH**
 - Hit `build.bat` or `run.bat`

## VS Code Setup

`tasks.json`

```json
{
  "version": "2.0.0",
  "command": "",
  "args": [],
  "tasks": [
      {
        "label": "run",
        "type": "shell",
        "command": "${workspaceFolder}/run.bat",
        "presentation": {
          "reveal": "always",
          "clear": true
        }
      },
      {
          "label": "compile",
          "type": "shell",
          "command": "${workspaceFolder}/build.bat",
          "presentation": {
            "reveal": "always",
            "clear": true
          },
          "group": { 
            "kind":"build", 
            "isDefault":"true"
          },
      }
  ]
}
```

`launch.json`

```json
{
  "version": "0.2.0",
  "configurations": [
      {
          "type": "cppvsdbg",
          "request": "launch",
          "name": "Debug",
          "console": "integratedTerminal",
          "preLaunchTask": "compile",
          "program": "${workspaceFolder}/game/bin/game.exe",
          "args": [],
          "cwd": "${workspaceFolder}/game/bin",
      }
  ]
}
```