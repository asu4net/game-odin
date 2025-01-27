package game

/////////////////////////////
//:Entity flags
/////////////////////////////

PLAYER_FLAGS : Entity_Flag_Set : {
    .PLAYER,
    .SPRITE,
}

ENEMY_SAW_FLAGS : Entity_Flag_Set : {
    .ENEMY,
    .SAW,
    .SPRITE,
}

/////////////////////////////
//:Names
/////////////////////////////

PLAYER_NAME    :: "Player"
ENEMY_SAW_NAME :: "Enemy Saw"

/////////////////////////////
//:Paths
/////////////////////////////

PLAYER_TEXTURE_PATH    :: "assets/player.png"
ENEMY_SAW_TEXTURE_PATH :: "assets/enemy_saw.png"

/////////////////////////////
//:Numbers
/////////////////////////////

WINDOW_WIDTH  :: 720
WINDOW_HEIGHT :: 1280
PLAYER_SPEED  :: 5