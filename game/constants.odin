package game

GAME_TITLE :: "Blessed Bullets"

/////////////////////////////
//:Numbers
/////////////////////////////

// Window
WINDOW_WIDTH                :: 720
WINDOW_HEIGHT               :: 1280

// Player
PLAYER_SPEED                :: 7.0
PLAYER_FIRERATE             :: 0.3

// Camera
CAMERA_SIZE                 :: 3.0 * 1.7

// Render 2D
MAX_2D_PRIMITIVES_PER_BATCH :: 3000
MAX_TEXTURE_SLOTS           :: 32

// Entity
MAX_ENTITIES                :: 3000

// Kamikaze
KAMIKAZE_WAVE_0_AMOUNT :: 5   // not implemented
KAMIKAZE_SPEED_MIN     :: 0   // min speed
KAMIKAZE_SPEED         :: 8   // max speed
KAMIKAZE_ACC           :: 0.7 // time to accelerate at max speed
KAMIKAZE_LIFE          :: 10  // not implemented
KAMIKAZE_SCORE         :: 10  // not implemented
KAMIKAZE_ATTACK_CD     :: 1
KAMIKAZE_SAW_SPEED     :: 360 * 2 // degrees per sec

/////////////////////////////
//:Names
/////////////////////////////

NAME_PLAYER        :: "Player"
NAME_KAMIKAZE      :: "KamikazePrefab"
NAME_KAMIKAZE_SAW  :: "KamikazeSawPrefab"

/////////////////////////////
//:Debug
/////////////////////////////

DEBUG_AI_MOVEMENT_ENABLED      :: true
DEBUG_DRAW_COLLIDERS           :: true
DEBUG_PRINT_CREATED_ENTITIES   :: false
DEBUG_PRINT_DESTROYED_ENTITIES :: false