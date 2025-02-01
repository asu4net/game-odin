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
KAMIKAZE_WAVE_0_AMOUNT :: 5
KAMIKAZE_SPEED         :: 6  
KAMIKAZE_LIFE          :: 10
KAMIKAZE_SCORE         :: 10
KAMIKAZE_ATTACK_CD     :: 1
KAMIKAZE_SAW_SPEED     :: 360 * 2 // degrees per sec

/////////////////////////////
//:Names
/////////////////////////////

NAME_PLAYER        :: "Player"
NAME_KAMIKAZE      :: "KamikazePrefab"
NAME_KAMIKAZE_SAW  :: "KamikazeSawPrefab"

/////////////////////////////
//:Paths
/////////////////////////////

TEXTURE_PATH_PLAYER       :: "assets/textures/player.png" 
TEXTURE_PATH_KAMIKAZE     :: "assets/textures/kamikaze_skull.png"
TEXTURE_PATH_KAMIKAZE_SAW :: "assets/textures/kazmikaze_saw.png"

/////////////////////////////
//:Debug
/////////////////////////////

DEBUG_AI_MOVEMENT_ENABLED      :: true
DEBUG_DRAW_COLLIDERS           :: false
DEBUG_PRINT_CREATED_ENTITIES   :: false
DEBUG_PRINT_DESTROYED_ENTITIES :: false